# Music Database ETL Pipeline with SQLite and Shell Script

This project demonstrates a complete Extract, Transform, and Load (ETL) pipeline designed to build a clean, normalized, and query-ready music database from raw, inconsistent CSV files. The entire workflow is automated using a single shell script that orchestrates data operations within SQLite.

## Project Summary

The core challenge addressed by this project is the common issue of dealing with messy, real-world data. The initial music data was spread across multiple files and suffered from inconsistencies such as duplicate records, null values, and incorrect formatting, making it unsuitable for reliable analysis.

This solution implements a robust ETL pipeline that:
1.  **Extracts** data from raw CSV files.
2.  **Transforms** the data by cleaning and validating it in a temporary staging area.
3.  **Loads** the clean, structured data into a final, permanent relational database.

## Key Features

- **Automated Pipeline**: A single, executable shell script (`etl_script.sh`) manages the entire process from start to finish.
- **Staging Area for Data Integrity**: Uses temporary tables as a staging area to clean and validate data without compromising the integrity of the final tables.
- **Data Cleaning**: Implements SQL-based cleaning logic to handle duplicates, remove records with null values, and ensure relational consistency.
- **Normalized Database Schema**: The final database is structured with a clean, relational design, making it efficient for complex queries.

## Technology Stack

- **Database**: **SQLite** (for its lightweight, serverless, and file-based architecture)
- **Scripting**: **Shell Scripting (Bash)** (for automating command-line operations)
- **Execution Environment**: **Git Bash** (or any Unix-like terminal)
- **Core Tool**: **`sqlite3` Command-Line Interface (CLI)**

## Database Schema

The database is designed with four main tables that are linked through foreign key relationships to create a normalized structure.

### Entity-Relationship Diagram (ERD)

![ERD of the Music Database Schema](http://googleusercontent.com/file_content/1)
*A visual representation of the final database schema.*

- **`Genres`**: Stores unique music genre information.
- **`Artists`**: Contains details for each artist and links to a specific genre.
- **`Albums`**: Stores album information and links to the corresponding artist.
- **`Tracks`**: Contains individual track details and links to a specific album.

## The ETL Workflow

The `etl_script.sh` script executes the following sequence of operations:

1.  **Clear Previous Data**: Deletes all data from the final tables to ensure a fresh load every time the script is run.
2.  **Extract**: Imports data from the raw CSV files located in the `raw_data/` directory into temporary staging tables (`Artists_Temp`, `Albums_Temp`, etc.).
3.  **Transform**: Executes a series of SQL commands to clean and structure the data in the staging area. This includes:
    - **Validating Foreign Keys**: Removing records with invalid foreign keys (e.g., a track pointing to a non-existent album).
    - **Handling Nulls**: Deleting rows with missing critical data like names or titles.
    - **Removing Duplicates**: Using `GROUP BY` clauses to eliminate duplicate entries.
    - **Data Formatting**: Trimming whitespace and converting data types where necessary (e.g., converting track duration from minutes to seconds).
4.  **Load**: Inserts the clean data from the temporary tables (`Artists_Cleaned`, `Albums_Cleaned`, etc.) into the final, permanent tables.
5.  **Cleanup**: Drops all temporary tables from the database to leave behind a clean final product.

## How to Run the Project

### Prerequisites

- You must have **SQLite3** installed and accessible from your command line.
- A **Bash-compatible terminal** is required (e.g., Git Bash on Windows, or any standard terminal on macOS/Linux).

### Instructions

1.  **Clone the Repository**:
    ```bash
    git clone <your-repository-url>
    cd <your-repository-directory>
    ```

2.  **Set up the Directory Structure**: Ensure your project directory is organized as follows:
    ```
    .
    ├── database/
    │   └── iMediaMusicDB.sqlite  # Your SQLite database file
    ├── raw_data/
    │   ├── Artists_Raw.csv
    │   ├── Albums_Raw.csv
    │   ├── Tracks_Raw.csv
    │   └── Genres_Raw.csv
    └── etl_script.sh
    ```

3.  **Execute the ETL Script**: Run the following command in your terminal from the project's root directory.
    ```bash
    ./etl_script.sh
    ```
    You will see log messages in the terminal, and upon successful execution, the script will print: `ETL script completed successfully`. Your `iMediaMusicDB.sqlite` database will now be populated with clean data.


