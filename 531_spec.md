We are going to build a new app that manages an athlete's 5-3-1 strength training program.

UI
- Flutter

Backend
- Python
- FastAPI
- SQLite

Use Docker to containerize the backend.

To start with, we will implement the basic 4 day training program. The details of this are specified in @Book/02_Program/. The main lift to be done on each of the 4 days is specified. We will allow the user to select 1-3 accessory accessories for each day.

We need to have a main page where the user can register or login with a username and password. Once logging in, there should be a calendar page that shows a week view or a month view. The workouts that are planned according to the program. The user should be able to start a new program, select the number of days to train (4 is the only option to start), select which days to train, set the training max for each lift. This can be a one rep max (1RM) or a rep max, for which we'll calculate the 1RM. Then the user can select which accessory lifts to add. Accessory lifts are specified in @Book/16_Assistance_Exercises. After completing a 4 week cycle, we want to ask the user what the new training maxes should be. By default, we'll increase the lower body lifts (squat, deadlift) by 10 lbs and the upper body lifts (press, bench press) by 5 lbs. The user should also be able to set an end date for the program or specify the number of cycles. We will also allow the user to add different programs with different start dates. For example, in the future, we'll have the option to do the 2 day per week or 3 day per week program. A user might do a few cycles on the 4 day per week, and then switch to the 3 day per week option.