WITH KONTOCHECKS_FINISHED AS (
	SELECT DISTINCT ereignis.vorgangsnummer
	FROM "prod_rate_consumable"."rate_vorgang_neueste_ereignis_mit_betreuer_id" ereignis
	WHERE ereignis."ereignistype" = 'kontocheck-finished'
),
AnzahlVorgangsanlagenMitA2AKW AS (
	SELECT Jahr || '-' || KW AS "Jahr-KW",
		COUNT(1) AS TotalVorgangsanlagenMitA2A
	FROM (
			SELECT k.vorgangsnummer,
				CAST(
					EXTRACT(
						YEAR
						FROM vorgaenge.erstelltam
					) AS varchar(4)
				) AS Jahr,
				SUBSTR(
					'00' || CAST(
						EXTRACT(
							WEEK
							FROM vorgaenge.erstelltam
						) AS varchar(2)
					),
					-2
				) AS KW
			FROM "rate_vorgang_stammdaten_neuste_revision" vorgaenge
				LEFT OUTER JOIN KONTOCHECKS_FINISHED k ON vorgaenge.vorgangsnummer = k.vorgangsnummer
			WHERE vorgaenge.erstelltam >= CAST('2021-07-01' AS DATE)
				AND vorgaenge.erstelltam <= DATE_ADD('day', -28, current_date)
				AND k.vorgangsnummer IS NOT NULL -- Only get those with A2A
		) AS inner_subquery
	GROUP BY Jahr || '-' || KW
),
AnzahlVorgaengeMitA2AMitSalesNachmax28Tagen AS (
	SELECT Jahr || '-' || KW AS "Jahr-KW",
		COUNT(1) AS TotalVorgaengeMitA2AMitSalesNachmax28Tagen
	FROM (
			SELECT DISTINCT k.vorgangsnummer,
				CAST(
					EXTRACT(
						YEAR
						FROM sales.erstelltam
					) AS varchar(4)
				) AS Jahr,
				SUBSTR(
					'00' || CAST(
						EXTRACT(
							WEEK
							FROM sales.erstelltam
						) AS varchar(2)
					),
					-2
				) AS KW
			FROM "rate_sales_mit_vorgangsinfos_neuste_revision" sales
				LEFT OUTER JOIN KONTOCHECKS_FINISHED k ON sales.vorgangsnummer = k.vorgangsnummer
			WHERE sales.erstelltam >= CAST('2021-07-01' AS DATE)
				AND sales.erstelltam <= DATE_ADD('day', -28, current_date)
				AND DATE_DIFF(
					'day',
					sales.erstelltam,
					CAST(sales.unterschrieben_beide_zeit AS DATE)
				) <= 28
				AND sales.status = 'UNTERSCHRIEBEN_BEIDE'
				AND k.vorgangsnummer IS NOT NULL -- Only get those with A2A
		) AS inner_subquery
	GROUP BY Jahr || '-' || KW
),
AnzahlVorgangsanlagenOhneA2AKW AS (
	SELECT Jahr || '-' || KW AS "Jahr-KW",
		COUNT(1) AS TotalVorgangsanlagenOhneA2A
	FROM (
			SELECT DISTINCT vorgaenge.vorgangsnummer,
				CAST(
					EXTRACT(
						YEAR
						FROM vorgaenge.erstelltam
					) AS varchar(4)
				) AS Jahr,
				SUBSTR(
					'00' || CAST(
						EXTRACT(
							WEEK
							FROM vorgaenge.erstelltam
						) AS varchar(2)
					),
					-2
				) AS KW
			FROM "rate_vorgang_stammdaten_neuste_revision" vorgaenge
				LEFT OUTER JOIN KONTOCHECKS_FINISHED k ON vorgaenge.vorgangsnummer = k.vorgangsnummer
			WHERE vorgaenge.erstelltam >= CAST('2021-07-01' AS DATE)
				AND vorgaenge.erstelltam <= DATE_ADD('day', -28, current_date)
				AND k.vorgangsnummer IS NULL -- Only get those without A2A
		) AS inner_subquery
	GROUP BY Jahr || '-' || KW
),
AnzahlVorgaengeOhneA2AMitSalesNachmax28Tagen AS (
	SELECT Jahr || '-' || KW AS "Jahr-KW",
		COUNT(1) AS TotalVorgaengeOhneA2AMitSalesNachmax28Tagen
	FROM (
			SELECT DISTINCT sales.vorgangsnummer,
				CAST(
					EXTRACT(
						YEAR
						FROM sales.erstelltam
					) AS varchar(4)
				) AS Jahr,
				SUBSTR(
					'00' || CAST(
						EXTRACT(
							WEEK
							FROM sales.erstelltam
						) AS varchar(2)
					),
					-2
				) AS KW
			FROM "rate_sales_mit_vorgangsinfos_neuste_revision" sales
				LEFT OUTER JOIN KONTOCHECKS_FINISHED k ON sales.vorgangsnummer = k.vorgangsnummer
			WHERE sales.erstelltam >= CAST('2021-07-01' AS DATE)
				AND sales.erstelltam <= DATE_ADD('day', -28, current_date)
				AND DATE_DIFF(
					'day',
					sales.erstelltam,
					CAST(sales.unterschrieben_beide_zeit AS DATE)
				) <= 28
				AND sales.status = 'UNTERSCHRIEBEN_BEIDE'
				AND k.vorgangsnummer IS NULL -- Only get those without A2A
		) AS inner_subquery
	GROUP BY Jahr || '-' || KW
)
SELECT 
    vorgaenge."Jahr-KW",
    vorgaenge.TotalVorgangsanlagenOhneA2A,
    salesCount.TotalVorgaengeOhneA2AMitSalesNachmax28Tagen,
    round((salesCount.TotalVorgaengeOhneA2AMitSalesNachmax28Tagen * 100.0 / vorgaenge.TotalVorgangsanlagenOhneA2A),3) AS ConversionRateOhneA2A,
    a2aVorgaenge.TotalVorgangsanlagenMitA2A,
    a2aSales.TotalVorgaengeMitA2AMitSalesNachmax28Tagen,
    round((a2aSales.TotalVorgaengeMitA2AMitSalesNachmax28Tagen * 100.0 / a2aVorgaenge.TotalVorgangsanlagenMitA2A),3) AS ConversionRateMitA2A,
    round(((a2aSales.TotalVorgaengeMitA2AMitSalesNachmax28Tagen+salesCount.TotalVorgaengeOhneA2AMitSalesNachmax28Tagen)*100.0/(a2aVorgaenge.TotalVorgangsanlagenMitA2A+vorgaenge.TotalVorgangsanlagenOhneA2A)),3) AS ConversionRate
FROM 
    AnzahlVorgangsanlagenOhneA2AKW vorgaenge
LEFT JOIN 
    AnzahlVorgaengeOhneA2AMitSalesNachmax28Tagen salesCount 
ON 
    vorgaenge."Jahr-KW" = salesCount."Jahr-KW"
LEFT JOIN 
    AnzahlVorgangsanlagenMitA2AKW a2aVorgaenge 
ON 
    vorgaenge."Jahr-KW" = a2aVorgaenge."Jahr-KW"
LEFT JOIN 
    AnzahlVorgaengeMitA2AMitSalesNachmax28Tagen a2aSales 
ON 
    a2aVorgaenge."Jahr-KW" = a2aSales."Jahr-KW"
ORDER BY 
    vorgaenge."Jahr-KW" DESC
LIMIT 10;
