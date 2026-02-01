# 5/3/1 API Endpoints

## `/`

### GET
**Root**

Root endpoint.

## `/api/v1/analytics/programs/{program_id}/training-max-progression`

### GET
**Get training max progression**

Get training max progression over time for all lifts in a program.

## `/api/v1/analytics/programs/{program_id}/workout-history`

### GET
**Get workout history**

Get detailed workout history with performance statistics.

## `/api/v1/auth/login`

### POST
**Login user**

Authenticate a user with email and password. Returns authentication tokens.

## `/api/v1/auth/refresh`

### POST
**Refresh access token**

Get a new access token using a valid refresh token.

## `/api/v1/auth/register`

### POST
**Register a new user**

Create a new user account with email and password. Returns authentication tokens.

## `/api/v1/auth/request-password-reset`

### POST
**Request password reset**

Request a password reset email. (Not yet implemented)

## `/api/v1/auth/reset-password`

### POST
**Reset password**

Reset password using reset token. (Not yet implemented)

## `/api/v1/exercises`

### GET
**List exercises**

Get all available exercises (predefined from book + user's custom exercises).

### POST
**Create custom exercise**

Create a new custom exercise for the current user.

## `/api/v1/programs`

### GET
**List all programs**

Get all programs for the current user (active, completed, paused).

### POST
**Create a new program**

Create a new training program with training maxes, training days, and accessories.

## `/api/v1/programs/{program_id}`

### GET
**Get program details**

Get detailed information about a specific program.

### PUT
**Update program**

Update program name, status, or end date.

### DELETE
**Delete program**

Delete a program and all associated data (workouts, training maxes, etc.).

## `/api/v1/programs/{program_id}/complete-cycle`

### POST
**Complete cycle and increase training maxes**

Finish current cycle and automatically increase training maxes per 5/3/1 methodology.

## `/api/v1/programs/{program_id}/generate-next-cycle`

### POST
**Generate next 4-week cycle**

Create 16 new workouts for the next cycle using updated training maxes.

## `/api/v1/rep-maxes`

### GET
**Get all rep maxes**

Get personal records (rep maxes) for all lifts across all rep ranges (1-12).

## `/api/v1/rep-maxes/{lift_type}`

### GET
**Get rep maxes for specific lift**

Get personal records for a specific lift across all rep ranges (1-12).

## `/api/v1/users/me`

### GET
**Get current user**

Get the profile of the currently authenticated user.

### PUT
**Update current user**

Update the profile of the currently authenticated user.

## `/api/v1/warmup-templates`

### GET
**List warmup templates**

Get all warmup templates for the current user, optionally filtered by lift type.

### POST
**Create warmup template**

Create a new custom warmup template.

## `/api/v1/warmup-templates/{template_id}`

### GET
**Get warmup template**

Get a specific warmup template by ID.

### PUT
**Update warmup template**

Update an existing warmup template.

### DELETE
**Delete warmup template**

Delete a warmup template.

## `/api/v1/workouts`

### GET
**List workouts**

Get workouts for the current user with optional filters.

## `/api/v1/workouts/missed`

### GET
**Get missed workouts**

Get all workouts that are past their scheduled date but not completed.

## `/api/v1/workouts/{workout_id}`

### GET
**Get workout details**

Get detailed workout information including all prescribed sets.

## `/api/v1/workouts/{workout_id}/complete`

### POST
**Complete workout**

Log all sets, mark workout as completed, and get performance analysis.

## `/api/v1/workouts/{workout_id}/handle-missed`

### POST
**Handle missed workout**

Skip or reschedule a missed workout.

## `/api/v1/workouts/{workout_id}/skip`

### POST
**Skip workout**

Mark a workout as intentionally skipped.

## `/health`

### GET
**Health Check**

Health check endpoint.

