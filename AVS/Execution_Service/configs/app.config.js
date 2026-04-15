"use strict";
const env = require("dotenv")
env.config()
const express = require("express")
const app = express()
const path = require("path")
const taskController = require("../src/task.controller")
const analyticsController = require("../src/analytics.controller")
const userController = require("../src/user.controller")
const commentController = require("../src/comment.controller")
const leaderboardController = require("../src/leaderboard.controller")
const activityController = require("../src/activity.controller")
const cors = require('cors')


app.use(express.json())
app.use(cors())

// ── v0 unversioned mounts (backwards compat for existing Flutter clients) ──
app.use("/task", taskController)
app.use("/analytics", analyticsController)

// ── /api/v1 mounts (Phase 4 and forward) ──
app.use("/api/v1/task", taskController)
app.use("/api/v1/analytics", analyticsController)
app.use("/api/v1/users", userController)
app.use("/api/v1", commentController)       // /markets/:id/comments + /comments/:cid/like
app.use("/api/v1/leaderboard", leaderboardController)
app.use("/api/v1/activity", activityController)

module.exports = app