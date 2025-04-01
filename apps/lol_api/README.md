### Integration with Riot Games API  

In a real-world application, the user retrieves their **Platform Universal User Identifier (PUUID)** using one of the following methods:  
- **GET /lol/summoner/v4/summoners/me** — Get a summoner by access token  
- **GET /riot/account/v1/accounts/by-riot-id/{gameName}/{tagLine}** — Get account by Riot ID (exchange Riot ID for PUUID)  

In our showcase, we retrieve summoner IDs and PUUIDs using the following endpoints:  
- **GET /lol/league/v4/entries/{queue}/{tier}/{division}** — Get all the league entries (retrieve summoner ID)  
- **GET /lol/league/v4/entries/by-summoner/{encryptedSummonerId}** — Get league entries in all queues for a given summoner ID (retrieve PUUID)  

We randomly associate summoners with our users, allowing each user to have multiple summoners, while each summoner belongs to exactly one user.  

After obtaining the PUUID, the application uses it to fetch data for the last 30 matches via the following endpoint:  
- **GET /lol/match/v5/matches/by-puuid/{puuid}/ids** — Get a list of match IDs by PUUID  

Then, for each match ID, it retrieves the user's individual statistics using:  
- **GET /lol/match/v5/matches/{matchId}** — Get a match by match ID  
