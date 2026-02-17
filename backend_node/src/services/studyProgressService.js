const db = require('../db');

class StudyProgressService {
  /**
   * Track study session and update streaks
   */
  static async trackStudySession(userId, sessionData) {
    try {
      const { duration, subject, topics, score } = sessionData;
      
      // Get current streak
      const streakResult = await db.query(
        'SELECT current_streak, longest_streak, last_study_date FROM study_streaks WHERE user_id = $1',
        [userId]
      );
      
      const now = new Date();
      const lastStudyDate = streakResult.rows[0]?.last_study_date ? new Date(streakResult.rows[0].last_study_date) : null;
      const currentStreak = streakResult.rows[0]?.current_streak || 0;
      const longestStreak = streakResult.rows[0]?.longest_streak || 0;
      
      // Calculate new streak
      let newStreak = currentStreak;
      let streakMessage = '';
      
      if (!lastStudyDate) {
        newStreak = 1;
        streakMessage = '🔥 First study session! Keep it going!';
      } else {
        const daysDiff = Math.floor((now - lastStudyDate) / (1000 * 60 * 60 * 24));
        
        if (daysDiff === 0) {
          streakMessage = '👍 Great job studying again today!';
        } else if (daysDiff === 1) {
          newStreak = currentStreak + 1;
          if (newStreak > longestStreak) {
            streakMessage = '🎉 NEW RECORD! Streak updated to ' + newStreak + ' days!';
          } else {
            streakMessage = '🔥 Streak maintained: ' + newStreak + ' days!';
          }
        } else if (daysDiff <= 7) {
          streakMessage = '📅 Welcome back! Starting fresh streak.';
          newStreak = 1;
        } else {
          streakMessage = '🌱 Long time no see! Starting fresh.';
          newStreak = 1;
        }
      }
      
      // Update or insert streak
      if (streakResult.rows.length > 0) {
        await db.query(
          'UPDATE study_streaks SET current_streak = $1, longest_streak = GREATEST(longest_streak, $2), last_study_date = $3 WHERE user_id = $4',
          [newStreak, newStreak, now, userId]
        );
      } else {
        await db.query(
          'INSERT INTO study_streaks (user_id, current_streak, longest_streak, last_study_date) VALUES ($1, $2, $3, $4)',
          [userId, newStreak, newStreak, now]
        );
      }
      
      // Save study session
      await db.query(
        'INSERT INTO study_sessions (user_id, duration, subject, topics, score, session_date) VALUES ($1, $2, $3, $4, $5, $6)',
        [userId, duration, subject, JSON.stringify(topics), score, now]
      );
      
      // Get updated statistics
      const stats = await this.getStudyStatistics(userId);
      
      return {
        success: true,
        streakMessage,
        currentStreak: newStreak,
        longestStreak: Math.max(longestStreak, newStreak),
        statistics: stats,
      };
    } catch (error) {
      console.error('Track Study Session Error:', error);
      return {
        success: false,
        error: error.message,
      };
    }
  }
  
  /**
   * Get comprehensive study statistics
   */
  static async getStudyStatistics(userId) {
    try {
      // Get total study time
      const totalTimeResult = await db.query(
        'SELECT SUM(duration) as total_time, COUNT(*) as total_sessions FROM study_sessions WHERE user_id = $1',
        [userId]
      );
      
      // Get subject breakdown
      const subjectBreakdownResult = await db.query(
        'SELECT subject, SUM(duration) as total_time, COUNT(*) as sessions FROM study_sessions WHERE user_id = $1 GROUP BY subject ORDER BY total_time DESC',
        [userId]
      );
      
      // Get weekly progress
      const weeklyResult = await db.query(
        'SELECT DATE(session_date) as date, SUM(duration) as daily_time FROM study_sessions WHERE user_id = $1 AND session_date >= NOW() - INTERVAL \'7 days\' GROUP BY DATE(session_date) ORDER BY date',
        [userId]
      );
      
      // Get achievement progress
      const achievementsResult = await db.query(
        'SELECT achievement_type, progress, unlocked_at FROM user_achievements WHERE user_id = $1',
        [userId]
      );
      
      // Get current streak info
      const streakResult = await db.query(
        'SELECT current_streak, longest_streak, last_study_date FROM study_streaks WHERE user_id = $1',
        [userId]
      );
      
      const totalTime = parseInt(totalTimeResult.rows[0]?.total_time || 0);
      const totalSessions = parseInt(totalTimeResult.rows[0]?.total_sessions || 0);
      const avgSessionTime = totalSessions > 0 ? Math.round(totalTime / totalSessions) : 0;
      
      return {
        totalStudyTime: totalTime,
        totalSessions,
        averageSessionTime: avgSessionTime,
        subjectBreakdown: subjectBreakdownResult.rows,
        weeklyProgress: weeklyResult.rows,
        achievements: achievementsResult.rows,
        currentStreak: streakResult.rows[0]?.current_streak || 0,
        longestStreak: streakResult.rows[0]?.longest_streak || 0,
        lastStudyDate: streakResult.rows[0]?.last_study_date,
      };
    } catch (error) {
      console.error('Get Study Statistics Error:', error);
      throw error;
    }
  }
  
  /**
   * Get leaderboard rankings
   */
  static async getLeaderboard(type = 'weekly', limit = 10) {
    try {
      let query = '';
      let timeFilter = '';
      
      switch (type) {
        case 'daily':
          timeFilter = 'AND session_date >= CURRENT_DATE';
          break;
        case 'weekly':
          timeFilter = 'AND session_date >= NOW() - INTERVAL \'7 days\'';
          break;
        case 'monthly':
          timeFilter = 'AND session_date >= NOW() - INTERVAL \'30 days\'';
          break;
        default:
          timeFilter = '';
      }
      
      query = `
        SELECT 
          u.id,
          u.name,
          u.profile_image_url,
          COALESCE(SUM(s.duration), 0) as total_time,
          COUNT(s.id) as sessions,
          COALESCE(st.current_streak, 0) as current_streak
        FROM users u
        LEFT JOIN study_sessions s ON u.id = s.user_id ${timeFilter}
        LEFT JOIN study_streaks st ON u.id = st.user_id
        GROUP BY u.id, u.name, u.profile_image_url, st.current_streak
        ORDER BY total_time DESC
        LIMIT $1
      `;
      
      const result = await db.query(query, [limit]);
      
      return {
        success: true,
        leaderboard: result.rows.map((user, index) => ({
          rank: index + 1,
          ...user,
          total_time: parseInt(user.total_time),
          sessions: parseInt(user.sessions),
        })),
      };
    } catch (error) {
      console.error('Get Leaderboard Error:', error);
      return {
        success: false,
        error: error.message,
      };
    }
  }
  
  /**
   * Check and award achievements
   */
  static async checkAchievements(userId) {
    try {
      const stats = await this.getStudyStatistics(userId);
      const newAchievements = [];
      
      // Time-based achievements
      if (stats.totalStudyTime >= 60 && !this.hasAchievement(stats.achievements, 'hour_power')) {
        await this.awardAchievement(userId, 'hour_power', '⚡ Hour Power', 'Study for 1 hour total');
        newAchievements.push('⚡ Hour Power');
      }
      
      if (stats.totalStudyTime >= 300 && !this.hasAchievement(stats.achievements, 'study_warrior')) {
        await this.awardAchievement(userId, 'study_warrior', '🗡️ Study Warrior', 'Study for 5 hours total');
        newAchievements.push('🗡️ Study Warrior');
      }
      
      if (stats.totalStudyTime >= 1000 && !this.hasAchievement(stats.achievements, 'study_master')) {
        await this.awardAchievement(userId, 'study_master', '🏆 Study Master', 'Study for 1000 hours total');
        newAchievements.push('🏆 Study Master');
      }
      
      // Streak-based achievements
      if (stats.currentStreak >= 7 && !this.hasAchievement(stats.achievements, 'week_warrior')) {
        await this.awardAchievement(userId, 'week_warrior', '🔥 Week Warrior', 'Maintain 7-day streak');
        newAchievements.push('🔥 Week Warrior');
      }
      
      if (stats.currentStreak >= 30 && !this.hasAchievement(stats.achievements, 'month_legend')) {
        await this.awardAchievement(userId, 'month_legend', '👑 Month Legend', 'Maintain 30-day streak');
        newAchievements.push('👑 Month Legend');
      }
      
      // Session-based achievements
      if (stats.totalSessions >= 10 && !this.hasAchievement(stats.achievements, 'consistent_learner')) {
        await this.awardAchievement(userId, 'consistent_learner', '📚 Consistent Learner', 'Complete 10 study sessions');
        newAchievements.push('📚 Consistent Learner');
      }
      
      return {
        success: true,
        newAchievements,
        totalAchievements: stats.achievements.length + newAchievements.length,
      };
    } catch (error) {
      console.error('Check Achievements Error:', error);
      return {
        success: false,
        error: error.message,
      };
    }
  }
  
  /**
   * Helper method to check if user has achievement
   */
  static hasAchievement(achievements, achievementType) {
    return achievements.some(achievement => achievement.achievement_type === achievementType);
  }
  
  /**
   * Award achievement to user
   */
  static async awardAchievement(userId, achievementType, title, description) {
    await db.query(
      'INSERT INTO user_achievements (user_id, achievement_type, title, description, unlocked_at) VALUES ($1, $2, $3, $4, NOW())',
      [userId, achievementType, title, description]
    );
  }
  
  /**
   * Get study goals and progress
   */
  static async getStudyGoals(userId) {
    try {
      const result = await db.query(
        'SELECT * FROM study_goals WHERE user_id = $1 AND is_active = true ORDER BY created_at DESC',
        [userId]
      );
      
      return {
        success: true,
        goals: result.rows.map(goal => ({
          ...goal,
          progress: this.calculateGoalProgress(goal, userId),
        })),
      };
    } catch (error) {
      console.error('Get Study Goals Error:', error);
      return {
        success: false,
        error: error.message,
      };
    }
  }
  
  /**
   * Set study goal
   */
  static async setStudyGoal(userId, goalData) {
    try {
      const { type, target, timeframe, subject } = goalData;
      
      const result = await db.query(
        'INSERT INTO study_goals (user_id, type, target, timeframe, subject, created_at) VALUES ($1, $2, $3, $4, $5, NOW()) RETURNING *',
        [userId, type, target, timeframe, subject]
      );
      
      return {
        success: true,
        goal: result.rows[0],
      };
    } catch (error) {
      console.error('Set Study Goal Error:', error);
      return {
        success: false,
        error: error.message,
      };
    }
  }
  
  /**
   * Calculate progress for a goal
   */
  static async calculateGoalProgress(goal, userId) {
    try {
      const now = new Date();
      let progress = 0;
      
      switch (goal.type) {
        case 'daily_minutes':
          const todayResult = await db.query(
            'SELECT COALESCE(SUM(duration), 0) as total FROM study_sessions WHERE user_id = $1 AND DATE(session_date) = CURRENT_DATE',
            [userId]
          );
          progress = Math.min(100, (parseInt(todayResult.rows[0]?.total || 0) / goal.target) * 100);
          break;
          
        case 'weekly_hours':
          const weekResult = await db.query(
            'SELECT COALESCE(SUM(duration), 0) as total FROM study_sessions WHERE user_id = $1 AND session_date >= NOW() - INTERVAL \'7 days\'',
            [userId]
          );
          progress = Math.min(100, (parseInt(weekResult.rows[0]?.total || 0) / (goal.target * 60)) * 100);
          break;
          
        case 'subject_mastery':
          const subjectResult = await db.query(
            'SELECT COUNT(*) as completed FROM study_sessions WHERE user_id = $1 AND subject = $2',
            [userId, goal.subject]
          );
          progress = Math.min(100, (parseInt(subjectResult.rows[0]?.completed || 0) / goal.target) * 100);
          break;
      }
      
      return Math.round(progress);
    } catch (error) {
      console.error('Calculate Goal Progress Error:', error);
      return 0;
    }
  }
}

module.exports = StudyProgressService;