#!/bin/bash
echo "ETL script started"

sqlite3 database/iMediaMusicDB.sqlite <<EOF

-- Temporarily disable foreign key constraints
PRAGMA foreign_keys = OFF;

-- Clear existing data
DELETE FROM Genres;
DELETE FROM Artists;
DELETE FROM Albums;
DELETE FROM Tracks;


-- Re-enable foreign key constraints
PRAGMA foreign_keys = ON;


-- Extract
.mode csv
.import 'raw_data/Artists_Raw.csv' Artists_Temp
.import 'raw_data/Albums_Raw.csv' Albums_Temp
.import 'raw_data/Tracks_Raw.csv' Tracks_Temp
.import 'raw_data/Genres_Raw.csv' Genres_Temp

-- Validate and clean the temporary tables
-- Ensure GenreID in Artists_Temp is valid
DELETE FROM Artists_Temp WHERE GenreID NOT IN (SELECT GenreID FROM Genres_Temp);

-- Ensure ArtistID in Albums_Temp is valid
DELETE FROM Albums_Temp WHERE ArtistID NOT IN (SELECT ArtistID FROM Artists_Temp);

-- Ensure AlbumID in Tracks_Temp is valid
DELETE FROM Tracks_Temp WHERE AlbumID NOT IN (SELECT AlbumID FROM Albums_Temp);


-- Transform
-- Artists Table
CREATE TABLE Artists_Cleaned AS SELECT * FROM Artists_Temp;
DELETE FROM Artists_Cleaned WHERE Name IS NULL OR Name = '';
DELETE FROM Artists_Cleaned WHERE rowid NOT IN (SELECT MIN(rowid) FROM Artists_Cleaned GROUP BY ArtistID);
UPDATE Artists_Cleaned SET Name = TRIM(Name);

-- Ensure ArtistID in Albums_Temp is valid
DELETE FROM Albums_Temp WHERE ArtistID NOT IN (SELECT ArtistID FROM Artists_Temp);

-- Albums Table
CREATE TABLE Albums_Cleaned AS SELECT * FROM Albums_Temp;
DELETE FROM Albums_Cleaned WHERE Title IS NULL OR Title = '';
DELETE FROM Albums_Cleaned WHERE rowid NOT IN (SELECT MIN(rowid) FROM Albums_Cleaned GROUP BY AlbumID);
UPDATE Albums_Cleaned SET Title = TRIM(Title);

-- Ensure ArtistID in Albums_Cleaned is valid (post-transformation validation)
DELETE FROM Albums_Cleaned WHERE ArtistID NOT IN (SELECT ArtistID FROM Artists_Cleaned);


-- Tracks Table
CREATE TABLE Tracks_Cleaned AS SELECT * FROM Tracks_Temp;
DELETE FROM Tracks_Cleaned WHERE Title IS NULL OR Title = '';
UPDATE Tracks_Cleaned SET Duration = Duration * 60; -- Assuming Duration was in minutes, convert to seconds
DELETE FROM Tracks_Cleaned WHERE Duration <= 0; -- Ensure Duration is greater than 0

-- Ensure AlbumID in Tracks_Cleaned is valid (post-transformation validation)
DELETE FROM Tracks_Cleaned WHERE AlbumID NOT IN (SELECT AlbumID FROM Albums_Cleaned);

-- Genres Table
CREATE TABLE Genres_Cleaned AS SELECT * FROM Genres_Temp;
DELETE FROM Genres_Cleaned WHERE Name IS NULL OR Name = '';

-- Load
PRAGMA foreign_keys = OFF;

INSERT INTO Genres (GenreID, Name)
SELECT GenreID, Name FROM Genres_Cleaned;

INSERT INTO Artists (ArtistID, Name, BirthDate, GenreID)
SELECT ArtistID, Name, BirthDate, GenreID FROM Artists_Cleaned;

INSERT INTO Albums (AlbumID, Title, ReleaseDate, ArtistID)
SELECT AlbumID, Title, ReleaseDate, ArtistID FROM Albums_Cleaned;

INSERT INTO Tracks (TrackID, Title, Duration, AlbumID)
SELECT TrackID, Title, Duration, AlbumID FROM Tracks_Cleaned
WHERE Duration > 0; -- Ensure Duration is greater than 0

PRAGMA foreign_keys = ON;

-- Clean up
DROP TABLE IF EXISTS Artists_Temp;
DROP TABLE IF EXISTS Albums_Temp;
DROP TABLE IF EXISTS Tracks_Temp;
DROP TABLE IF EXISTS Genres_Temp;

DROP TABLE IF EXISTS Artists_Cleaned;
DROP TABLE IF EXISTS Albums_Cleaned;
DROP TABLE IF EXISTS Tracks_Cleaned;
DROP TABLE IF EXISTS Genres_Cleaned;
EOF

if [ $? -eq 0 ]; then
    echo "ETL script completed successfully"
else
    echo "ETL script encountered an error"
fi

echo "ETL script ended"
