-- MLB EDA Project using 4 tables (players, salaries, schools & school details)

-- PART I: SCHOOL ANALYSIS


--  In each decade, how many schools were there that produced players? 
SELECT ROUND(yearID,-1) as decade, COUNT(DISTINCT schoolID) AS num_schools
FROM schools
GROUP BY decade 
ORDER BY decade DESC;


-- What are the names of the top 5 schools that produced the most players?
SELECT s.schoolID, sd.name_full, COUNT(DISTINCT s.playerID) as num_players
FROM schools s LEFT JOIN school_details sd
ON s.schoolID = sd.schoolID
GROUP BY s.schoolID, sd.name_full
ORDER BY num_players DESC
LIMIT 5;

-- schools producing players with the longest careers


WITH player_career_length AS
			(SELECT 
				p.playerID,
				p.nameGiven,
				s.schoolID,
				MAX(YEAR(p.debut)) AS debut_year,
				MAX(YEAR(p.finalGame)) as final_year,
				MAX(YEAR(p.finalGame)) - MIN(YEAR(p.debut)) AS career_length_years
			FROM players p LEFT JOIN schools s
				ON p.playerID = s.playerID
			WHERE p.debut IS NOT NULL
				AND p.finalGame IS NOT NULL
				AND s.schoolID IS NOT NULL
			GROUP BY 
				playerID,
				nameGiven,
				s.schoolID)
SELECT 
	pcl.schoolID,
    sd.name_full,
	COUNT(pcl.playerID) AS num_players,
    AVG(career_length_years) AS avg_career_length,
    MAX(career_length_years) AS longest_career_length
FROM player_career_length pcl LEFT JOIN school_details sd
	ON pcl.schoolID = sd.schoolID
WHERE debut_year > 1990
GROUP BY 
	pcl.schoolID,
    sd.name_full
ORDER BY num_players DESC, avg_career_length DESC
LIMIT 10;




-- For each decade, what were the names of the top 3 schools that produced the most players? 
WITH decades_schools AS 		
        (SELECT ROUND(s.yearID,-1) AS decade, sd.name_full, COUNT(DISTINCT s.playerID) as num_players
		FROM schools s LEFT JOIN school_details sd
		ON s.schoolID = sd.schoolID
		GROUP BY decade, sd.name_full),
  
	dr AS
		(SELECT *,
		ROW_NUMBER() OVER (partition by decade ORDER BY num_players DESC) AS decade_rank
		FROM decades_schools)
SELECT decade, name_full, num_players 
FROM dr
WHERE decade_rank <= 3
ORDER BY decade DESC, decade_rank;



-- PART II: SALARY ANALYSIS


-- Return the top 20% of teams in terms of average annual spending 

WITH ts AS 
		(SELECT teamID, yearID, SUM(salary) AS total_spend
		FROM salaries 
		GROUP BY teamID, yearID
		ORDER BY teamID, yearID),
        
     sp AS
		(SELECT teamID, ROUND(AVG(total_spend),2) AS avg_total_spend,
						NTILE(5) OVER (ORDER BY ROUND(AVG(total_spend),2) DESC) AS spend_percentile
		FROM ts
		GROUP BY teamID)
        
SELECT teamID, ROUND(avg_total_spend/1000000,1) AS avg_spend_in_millions
FROM sp
WHERE spend_percentile = 1;




-- For each team, show the cumulative sum of spending over the years 
SELECT * 
FROM salaries;


WITH ts AS
		(SELECT teamID, yearID, SUM(salary) AS total_spend
		FROM salaries 
		GROUP BY teamID, yearID
		ORDER BY teamID, yearID)
SELECT teamID, yearID,
		ROUND(SUM(total_spend) OVER (PARTITION BY teamID ORDER BY yearID)/1000000,1) AS cum_sales_millions
FROM ts;

-- Return the first year that each team's cumulative spending surpassed 1 billion [Min / Max Value Filtering]
WITH ts AS
		(SELECT teamID, yearID, SUM(salary) AS total_spend
		FROM salaries 
		GROUP BY teamID, yearID
		ORDER BY teamID, yearID),
  
	cs AS
		(SELECT teamID, yearID,
			SUM(total_spend) OVER (PARTITION BY teamID ORDER BY yearID) AS cum_sales
		FROM ts),

    sr AS 
		(SELECT teamID, yearID, cum_sales,
				ROW_NUMBER() OVER (PARTITION BY teamID ORDER BY yearID) AS sales_rank
		FROM cs
		WHERE cum_sales > 1000000000)
SELECT teamID, yearID, ROUND(cum_sales/1000000000,2) AS cum_sum_billions
FROM sr
WHERE sales_rank = 1;

-- average tenure of players against total salary allocated  (retention efficinecy)
SELECT * 
FROM salaries;

WITH player_tenure AS
		(SELECT 
			playerID,
            teamID,
            MIN(yearID) AS debut_year,
            MAX(yearID) AS final_year,
            COUNT(DISTINCT yearID) AS tenure_years
		FROM salaries
        GROUP BY playerID, teamID),
		
        team_salary AS 
			(SELECT
				playerID,
                teamID,
                SUM(salary) AS total_salary
			FROM salaries 
            GROUP BY playerID, teamID)

SELECT
	pt.teamID,
    COUNT(pt.playerID) as num_players,
    AVG(pt.tenure_years) AS avg_tenure_length,
    SUM(ts.total_salary) AS total_salary_allocated,
    (SUM(total_salary) / NULLIF(SUM(pt.tenure_years),0)) AS avg_salary_per_year
FROM player_tenure pt LEFT JOIN team_salary ts 
			ON pt.playerID = ts.playerID AND pt.teamID = ts.teamID
GROUP BY pt.teamID
ORDER BY avg_salary_per_year ASC;

-- PART III: PLAYER CAREER ANALYSIS

-- View the players table and find the number of players in the table
SELECT * FROM players;
SELECT COUNT(*) FROM players;

-- TASK 2: For each player, calculate their age at their first (debut) game, their last game,
-- and their career length (all in years). Sort from longest career to shortest career. 
WITH bd AS
		(SELECT playerID, nameGiven, birthYear, birthMonth, birthDay, debut,finalGame,
				CAST(CONCAT(birthYear,'-', birthMonth,'-', birthDay) AS DATE) AS birthdate
		FROM players)

SELECT playerID, nameGiven, TIMESTAMPDIFF(YEAR, birthdate,debut) AS debut_age,
TIMESTAMPDIFF(YEAR,birthdate,finalGame) AS last_game_age,
TIMESTAMPDIFF(YEAR,debut,finalGame) AS career_length
FROM bd
ORDER BY career_length DESC;

--  What team did each player play on for their starting and ending years? 
SELECT *
FROM players;

SELECT *
FROM salaries;

SELECT p.playerID, p.nameGiven, s.yearID AS starting_year, s.teamID  AS starting_year_team,
 e.yearID AS ending_year, e.teamID AS ending_year_team
FROM players p INNER JOIN salaries s
ON p.playerID = s.playerID
AND YEAR(p.debut) = s. yearID
				INNER JOIN salaries e
                ON p.playerID = e.playerID
				AND YEAR(p.finalGame) = e.yearID;


-- How many players started and ended on the same team and also played for over a decade?
WITH starting_ending_team AS
		(SELECT p.playerID, p.nameGiven, s.yearID AS starting_year, s.teamID AS starting_year_team,
		e.yearID AS ending_year, e.teamID AS ending_year_team
		FROM players p INNER JOIN salaries s
				ON p.playerID = s.playerID
				AND YEAR(p.debut) = s. yearID
						INNER JOIN salaries e
						ON p.playerID = e.playerID
						AND YEAR(p.finalGame) = e.yearID
		WHERE s.teamID = e.teamID
		AND e.yearID - s.yearID > 10)
        
SELECT COUNT(*)
FROM starting_ending_team;

--  View the players table
SELECT * FROM players;

-- TASK 2: Which players have the same birthday? 
WITH bd AS 
		(SELECT nameGiven, CAST(CONCAT(birthYear,'-', birthMonth,'-', birthDay) AS DATE) AS birthdate
		FROM players)
        
SELECT birthdate, GROUP_CONCAT(nameGiven SEPARATOR ', ') AS players
FROM bd
WHERE YEAR(birthdate) BETWEEN 1980 AND 1990
GROUP BY birthdate 
ORDER BY birthdate;


-- Create a summary table that shows for each team, what percent of players bat right, left and both 
SELECT  s.teamID, 
		ROUND(SUM(CASE WHEN bats = 'R' THEN 1 ELSE 0 END)/COUNT(s.playerID)*100,1) AS 'bats_right',
        ROUND(SUM(CASE WHEN bats = 'L' THEN 1 ELSE 0 END) /COUNT(s.playerID)*100,1) AS 'bats_left',
        ROUND(SUM(CASE WHEN bats = 'B' THEN 1 ELSE 0 END)/COUNT(s.playerID)*100,1)  AS 'bats_both'
FROM players p LEFT JOIN salaries s
ON p.playerID = s.playerID
GROUP BY s.teamID;

--  How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference?
WITH hw AS 
		(SELECT ROUND(YEAR(debut),-1) AS decade, AVG(weight) AS avg_weight, AVG(height) AS avg_height			
		FROM players
		GROUP BY decade)
        
SELECT decade,
		avg_weight - LAG(avg_weight) OVER (ORDER BY decade) AS weight_diff,
        avg_height - LAG(avg_height) OVER (ORDER BY decade) AS height_diff
FROM hw
WHERE decade IS NOT NULL;





