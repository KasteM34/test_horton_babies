SELECT
	n.name,
	am.gender,
	am.year,
	am.count
FROM
	us_baby_names_db.mynationalnames n
INNER JOIN (
	SELECT 
		gender,
		year,
		MAX(count) as count
	FROM
		us_baby_names_db.mynationalnames
	GROUP BY
		year, gender
)	am ON n.count = am.count AND n.year = am.year AND n.gender = am.gender
ORDER BY am.year DESC, am.gender DESC
