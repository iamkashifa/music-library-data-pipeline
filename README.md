#!/bin/bash

# ==============================================================================
# Music Database ETL Script
#
# Description:
# This script automates the ETL (Extract, Transform, Load) process for the
# music database project. It performs the following steps:
# 1.  Defines the database file and raw data locations.
# 2.  Drops old tables to ensure a fresh start.
# 3.  Creates the final, normalized tables (Genres, Artists, Albums, Tracks).
# 4.  Creates temporary staging tables for raw data.
# 5.  (EXTRACT) Imports data from CSV files into the temporary tables.
# 6.  (TRANSFORM) Cleans the data in the temporary tables by:
#     - Removing duplicate entries.
#     - Deleting rows with critical null values.
# 7.  (LOAD) Transfers the clean data from temporary tables into the final tables.
# 8.  Cleans up by dropping the temporary tables.
#
# Usage:
# Run this script from your terminal: ./etl_script.sh
#
# ==============================================================================

# --- Configuration ---
DB_FILE="music.db"
RAW_DATA_DIR="raw_data"

# --- Start of ETL Process ---
echo "Starting the Music Database ETL process..."

# Execute all SQL commands within a single sqlite3 session
sqlite3 ${DB_FILE} <<'END_SQL'

-- Turn on foreign key support
PRAGMA foreign_keys = ON;

-- ==============================================================================
-- STEP 1: DROP EXISTING TABLES (for a clean, repeatable run)
-- ==============================================================================
echo "Dropping old tables if they exist..."
DROP TABLE IF EXISTS Tracks;
DROP TABLE IF EXISTS Albums;
DROP TABLE IF EXISTS Artists;
DROP TABLE IF EXISTS Genres;
DROP TABLE IF EXISTS Media; -- As mentioned in presentation

-- ==============================================================================
-- STEP 2: CREATE FINAL, NORMALIZED TABLES
-- ==============================================================================
echo "Creating final, normalized tables..."

CREATE TABLE Genres (
    GenreID INTEGER PRIMARY KEY AUTOINCREMENT,
    Name TEXT NOT NULL UNIQUE
);

CREATE TABLE Artists (
    ArtistID INTEGER PRIMARY KEY AUTOINCREMENT,
    Name TEXT NOT NULL,
    BirthDate TEXT,
    GenreID INTEGER,
    FOREIGN KEY (GenreID) REFERENCES Genres(GenreID)
);

CREATE TABLE Albums (
    AlbumID INTEGER PRIMARY KEY AUTOINCREMENT,
    Title TEXT NOT NULL,
    ReleaseDate TEXT,
    ArtistID INTEGER NOT NULL,
    FOREIGN KEY (ArtistID) REFERENCES Artists(ArtistID)
);

CREATE TABLE Tracks (
    TrackID INTEGER PRIMARY KEY AUTOINCREMENT,
    Title TEXT NOT NULL,
    Duration INTEGER, -- Assuming duration is in seconds
    AlbumID INTEGER NOT NULL,
    FOREIGN KEY (AlbumID) REFERENCES Albums(AlbumID)
);

-- Example of creating the new Media table mentioned in the presentation
CREATE TABLE Media (
    MediaID INTEGER PRIMARY KEY AUTOINCREMENT,
    Format TEXT NOT NULL, -- e.g., 'MP3', 'WAV'
    TrackID INTEGER NOT NULL,
    FOREIGN KEY (TrackID) REFERENCES Tracks(TrackID)
);


-- ==============================================================================
-- STEP 3: CREATE TEMPORARY STAGING TABLES
-- ==============================================================================
echo "Creating temporary staging tables..."
DROP TABLE IF EXISTS temp_Artists;
DROP TABLE IF EXISTS temp_Albums;
DROP TABLE IF EXISTS temp_Tracks;
DROP TABLE IF EXISTS temp_Genres;

CREATE TABLE temp_Genres (
    Name TEXT
);

CREATE TABLE temp_Artists (
    Name TEXT,
    BirthDate TEXT,
    GenreName TEXT -- Storing genre by name initially
);

CREATE TABLE temp_Albums (
    Title TEXT,
    ReleaseDate TEXT,
    ArtistName TEXT -- Storing artist by name initially
);

CREATE TABLE temp_Tracks (
    Title TEXT,
    Duration INTEGER,
    AlbumTitle TEXT -- Storing album by title initially
);

.print "\n--- ETL Process Steps ---"
.print "Step 1 & 2: (EXTRACT/LOAD) Importing data from CSV to temporary tables..."
-- ==============================================================================
-- STEP 4: (EXTRACT) IMPORT DATA FROM CSV FILES INTO TEMP TABLES
-- Note: The .import command must be run outside the HERE document.
-- This part of the script handles that after the SQL block.
-- ==============================================================================

-- ==============================================================================
-- STEP 5: (TRANSFORM & LOAD) CLEAN AND TRANSFER DATA
-- ==============================================================================
.print "Step 3: (TRANSFORM) Cleaning and validating data..."

-- Populate Genres from unique, non-null genre names in temp_Artists
INSERT INTO Genres (Name)
SELECT DISTINCT GenreName FROM temp_Artists WHERE GenreName IS NOT NULL AND GenreName != '';

-- Populate Artists
-- We use a subquery to look up the GenreID from the Genres table
INSERT INTO Artists (Name, BirthDate, GenreID)
SELECT
    t.Name,
    t.BirthDate,
    (SELECT GenreID FROM Genres WHERE Name = t.GenreName)
FROM temp_Artists t
WHERE t.Name IS NOT NULL AND t.Name != '';

-- Populate Albums
-- We use a subquery to look up the ArtistID from the Artists table
INSERT INTO Albums (Title, ReleaseDate, ArtistID)
SELECT
    t.Title,
    t.ReleaseDate,
    (SELECT ArtistID FROM Artists WHERE Name = t.ArtistName)
FROM temp_Albums t
WHERE t.Title IS NOT NULL AND t.Title != ''
  AND t.ArtistName IS NOT NULL AND t.ArtistName != '';

-- Populate Tracks
-- We use a subquery to look up the AlbumID from the Albums table
INSERT INTO Tracks (Title, Duration, AlbumID)
SELECT
    t.Title,
    t.Duration,
    (SELECT AlbumID FROM Albums WHERE Title = t.AlbumTitle)
FROM temp_Tracks t
WHERE t.Title IS NOT NULL AND t.Title != ''
  AND t.AlbumTitle IS NOT NULL AND t.AlbumTitle != '';

.print "Step 4: (LOAD) Data has been loaded into final tables."

-- ==============================================================================
-- STEP 6: CLEANUP
-- ==============================================================================
.print "Cleaning up temporary tables..."
DROP TABLE temp_Genres;
DROP TABLE temp_Artists;
DROP TABLE temp_Albums;
DROP TABLE temp_Tracks;

.print "\nETL process completed successfully."

END_SQL

# --- .import commands need to be run separately ---
# The sqlite3 CLI's .import command doesn't work inside a multi-line SQL block
# passed via a HERE document. We run them here.

echo "Importing raw_data/genres.csv into temp_Genres..."
sqlite3 ${DB_FILE} ".mode csv" ".import ${RAW_DATA_DIR}/genres.csv temp_Genres"

echo "Importing raw_data/artists.csv into temp_Artists..."
sqlite3 ${DB_FILE} ".mode csv" ".import ${RAW_DATA_DIR}/artists.csv temp_Artists"

echo "Importing raw_data/albums.csv into temp_Albums..."
sqlite3 ${DB_FILE} ".mode csv" ".import ${RAW_DATA_DIR}/albums.csv temp_Albums"

echo "Importing raw_data/tracks.csv into temp_Tracks..."
sqlite3 ${DB_FILE} ".mode csv" ".import ${RAW_DATA_DIR}/tracks.csv temp_Tracks"


echo "Finalizing data transfer..."
# Re-run the INSERT statements now that the temp tables are populated
sqlite3 ${DB_FILE} <<'FINAL_LOAD'
PRAGMA foreign_keys = ON;

-- Populate Genres from unique, non-null genre names
INSERT OR IGNORE INTO Genres (Name)
SELECT DISTINCT Name FROM temp_Genres WHERE Name IS NOT NULL AND Name != '';

-- Populate Artists
INSERT OR IGNORE INTO Artists (Name, BirthDate, GenreID)
SELECT
    t.Name,
    t.BirthDate,
    (SELECT GenreID FROM Genres WHERE Name = t.GenreName)
FROM temp_Artists t
WHERE t.Name IS NOT NULL AND t.Name != '';

-- Populate Albums
INSERT OR IGNORE INTO Albums (Title, ReleaseDate, ArtistID)
SELECT
    t.Title,
    t.ReleaseDate,
    (SELECT ArtistID FROM Artists WHERE Name = t.ArtistName)
FROM temp_Albums t
WHERE t.Title IS NOT NULL AND t.Title != '';

-- Populate Tracks
INSERT OR IGNORE INTO Tracks (Title, Duration, AlbumID)
SELECT
    t.Title,
    t.Duration,
    (SELECT AlbumID FROM Albums WHERE Title = t.AlbumTitle)
FROM temp_Tracks t
WHERE t.Title IS NOT NULL AND t.Title != '';

-- Cleanup
DROP TABLE temp_Genres;
DROP TABLE temp_Artists;
DROP TABLE temp_Albums;
DROP TABLE temp_Tracks;

.print "Final data load complete. Database is ready."
FINAL_LOAD

echo "--- ETL Script Finished ---"

