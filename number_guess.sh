#!/bin/bash

PSQL="psql --username=freecodecamp --dbname=number_guess -t --no-align -c"

RANDOM_NUMBER="$(( $RANDOM % 1000 + 1))"
ATTEMPTS=0
INPUT_PROMPT="Guess the secret number between 1 and 1000:"
IS_NEW_USER=0

echo "Enter your username:"
read USER_NAME

# for new users
function greeting_new_user() {
  echo "Welcome, $USER_NAME! It looks like this is your first time here."
}

# for users already register
function greeting_user() {
  GAMES_PLAYED=$(echo $($PSQL "SELECT COUNT(*) FROM games_attempt WHERE user_id = $USER_ID") | xargs)
  BEST_GAME=$(echo $($PSQL "SELECT COALESCE(MIN(attempts), 0) FROM games_attempt WHERE user_id = $USER_ID") | xargs)

  echo "Welcome back, $USER_NAME! You have played $GAMES_PLAYED games, and your best game took $BEST_GAME guesses."
}

function main() {
  if [[ ! -z $USER_NAME ]]; then
    # find for user
    # USER_ID=$(echo $($PSQL -v user_name="'$USER_NAME'" "SELECT user_id FROM users WHERE user_name = :user_name" 2>/dev/null) | xargs)
    USER_ID=$(echo $($PSQL "SELECT user_id FROM users WHERE user_name = '$USER_NAME'") | xargs)
    # echo "$USER_NAME $USER_ID"
    
    # if user doesn't exist, create
    if [[ -z $USER_ID ]]; then
      # USER_ID=$($PSQL "INSERT INTO users(user_name) VALUES('$USER_NAME') RETURNING user_id") #> /dev/null 2>&1 ->redirige el flujo de error estándar (stderr) al mismo lugar donde se redirige la salida estándar (stdout)
      USER_ID=$(echo $($PSQL "INSERT INTO users(user_name) VALUES('$USER_NAME') RETURNING user_id") | xargs)
      USER_ID=${USER_ID%% *} #xpantion of var take only the first token

      # check result of insertion
      if [[ -z $USER_ID ]]; then
        echo "User name isn't valid!"
        exit 1
      fi

      IS_NEW_USER=1
    fi
  else
    exit 0
  fi

  # echo $USER_ID
  if [ $IS_NEW_USER -eq 1 ]; then
    greeting_new_user
  else
    greeting_user
  fi

  # play game
  while true; do
    echo $INPUT_PROMPT
    read USER_NUMBER_GUESS

    if [[ ! $USER_NUMBER_GUESS =~ ^[0-9]+$ ]]; then
      INPUT_PROMPT="That is not an integer, guess again:"
      continue
    elif [[ $RANDOM_NUMBER -eq $USER_NUMBER_GUESS ]]; then
      # save result on db
      ((ATTEMPTS+=1))
      # USER_ID was create previous under this block
      $PSQL "INSERT INTO games_attempt(user_id, attempts) VALUES($USER_ID, $ATTEMPTS)" > /dev/null # 2>&1

      if [[ $? -gt 0 ]]; then
        break
      fi

      echo "You guessed it in $ATTEMPTS tries. The secret number was $RANDOM_NUMBER. Nice job!"
      break
    elif [[ $RANDOM_NUMBER -lt $USER_NUMBER_GUESS ]]; then
      INPUT_PROMPT="It's lower than that, guess again:"
      ((ATTEMPTS+=1))
      continue
    else
      INPUT_PROMPT="It's higher than that, guess again:"
      ((ATTEMPTS+=1))
      continue
    fi
  done
}

main
