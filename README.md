## Introduction

### Project Overview  
The project is a distributed multi-node system that fetches data from the Riot API, aggregates it, and serves it through a GraphQL API to our users.  

### Goal and Objectives  
The primary goal of the project is to provide users with access to match statistics for the past 30 days in League of Legends for their selected players.  

### Expected Outcomes  
The system should be able to handle incoming requests at a rate of 2000 RPS.  

---

## Architecture

### Umbrella Application Structure  
The Umbrella Application will consist of five primary applications:  

1. **Data Fetcher Application** — responsible for collecting data from the Riot API and preparing it for database storage.  
2. **Schema Application** — manages database schemas and handles data aggregation.  
3. **Web Application** — provides a GraphQL API to access aggregated data.  
4. **Authentication Application** — identifies the current user.  
5. **Authorization Application** — determines what actions a user is allowed to perform within the system.  

---
