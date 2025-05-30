/* Skladište je napravljeno uz pomoć mentora/predavača odgovarajućeg kolegija 
    jer ipak je veći naglasak bio na obradi alata Amazon Redshift :) */

-- kreiranje dimenzije d_games
CREATE TABLE IF NOT EXISTS d_games
(
    games_id        SERIAL NOT NULL PRIMARY KEY,
    games_id_db     INT,
    games_year      SMALLINT,
    games_season    CHAR(10),
    games_name      VARCHAR(40),
    city_id_db      SMALLINT,
    city_name       VARCHAR,
    noc_id_db       CHAR(3),
    region          VARCHAR,
    total_medals    SMALLINT
);

-- punjenje dimenzije d_games

INSERT INTO d_games(games_id_db, games_year, games_season, games_name, 
city_id_db, city_name, noc_id_db, region)
SELECT  games_id,
        games_year,
        games_season,
        games_name,
        games.city_id,
        city_name,
        noc.noc_id,
        region
FROM games 
        LEFT JOIN city ON games.city_id = city.city_id 
        LEFT JOIN noc ON city.noc_id = noc.noc_id; 
UPDATE d_games 
SET total_medals = (SELECT COUNT(*)
                    FROM athlete_event 
                    WHERE athlete_event.games_id = d_games.games_id_db
                    AND medal_id IS NOT NULL);

-- kreiranje dimenzije d_athlete
CREATE TABLE IF NOT EXISTS d_athlete
(
    athlete_id          SERIAL NOT NULL PRIMARY KEY,
    athlete_id_db       INT,
    athlete_name        VARCHAR,
    athlete_gender      CHAR, 
    athlete_height      SMALLINT,
    athlete_weight      SMALLINT,
    athlete_yob         SMALLINT,
    athlete_noc_id_db   CHAR(3),
    athlete_noc_region  VARCHAR
);

-- punjenje dimenzije d_athlete
INSERT INTO d_athlete (athlete_id_db, athlete_name, athlete_gender,
                        athlete_height, athlete_weight, athlete_yob,
                        athlete_noc_id_db, athlete_noc_region)
SELECT DISTINCT athlete.athlete_id,
                athlete_name,
                athlete_gender, 
                athlete_height,
                athlete_weight,
                athlete_yob,
                noc.noc_id,
                region
FROM athlete_event 
        LEFT JOIN athlete ON athlete_event.athlete_id = athlete.athlete_id
        LEFT JOIN noc ON athlete_event.noc_id = noc.noc_id;

-- kreiranje i punjenje dimenzije d_event

CREATE TABLE IF NOT EXISTS d_event
(
    event_id    SERIAL NOT NULL PRIMARY KEY,
    event_id_db INT,
    event_name  VARCHAR,
    sport_id_db SMALLINT,
    sport_name  VARCHAR,
);

INSERT INTO d_event(event_id_db, event_name, sport_id_db, sport_name)
SELECT DISTINCT event_id, event_name, event.sport_id, sport_name
FROM event
        LEFT JOIN sport s ON event.sport_id = s.sport_id;

-- kreiranje činjenične tablice

CREATE TABLE IF NOT EXISTS f_participation
(
    athlete_id INTEGER,
    event_id   INTEGER,
    games_id   INTEGER,
    athlete_age INTEGER,
    home_field SMALLINT,
    medal      SMALLINT,
    gold       SMALLINT,
    silver     SMALLINT, 
    bronze     SMALLINT
);


-- punjenje činjenične tablice
INSERT INTO f_participation (athlete_id, event_id, games_id, athlete_age, home_field,
                            medal, gold, silver, bronze)
SELECT d_athlete.athlete_id,
        d_event.event_id,
        d_games.games_id,
        (d_games.games_year - d_athlete.athlete_yob),
        CASE WHEN d_games.noc_id_db = d_athlete.athlete_noc_id_db THEN 1 ELSE 0 END,
        CASE WHEN athlete_event_distinct.medal_id IS NULL THEN 0 ELSE 1 END,
        CASE WHEN athlete_event_distinct.medal_id = 1 THEN 1 ELSE 0 END,
        CASE WHEN athlete_event_distinct.medal_id = 2 THEN 1 ELSE 0 END,
        CASE WHEN athlete_event_distinct.medal_id = 3 THEN 1 ELSE 0 END
        
FROM (SELECT athlete_id, event_id, games_id, MIN(medal_id) AS medal_id
        FROM athlete_event
        GROUP BY 1, 2, 3) AS athlete_event_distinct
        
            JOIN d_athlete ON athlete_event_distinct.athlete_id = d_athlete.athlete_id_db
            JOIN d_event ON athlete_event_distinct.event_id = d_event.event_id_db
            JOIN d_games ON athlete_event_distinct.games_id = d_games.games_id_db;

-- sami ključevi u činjeničnoj tablici
ALTER TABLE f_participation
    ADD PRIMARY KEY (athlete_id, event_id, games_id);

ALTER TABLE f_participation
    ADD FOREIGN KEY (athlete_id) REFERENCES d_athlete;
ALTER TABLE f_participation
    ADD FOREIGN KEY (event_id) REFERENCES d_event;
ALTER TABLE f_participation
    ADD FOREIGN KEY (games_id) REFERENCES d_games;
