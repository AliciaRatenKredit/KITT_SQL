WITH KONTOCHECKS_FINISHED AS (
    SELECT 
        ereignis.vorgangsnummer
    FROM 
        "prod_rate_consumable"."rate_vorgang_neueste_ereignis_mit_betreuer_id" ereignis
    WHERE 
        ereignis."ereignistype" = 'kontocheck-finished'
),
AnzahlVorgangsanlagenMitA2AKW AS (
    SELECT
        Jahr || '-' || KW AS "Jahr-KW", --esto funciona
        COUNT(1) AS TotalVorgangsanlagenMitA2A --esto funciona
    FROM (
        SELECT 
            k.vorgangsnummer,
            CAST(EXTRACT(YEAR FROM vorgaenge.erstelltam) AS varchar(4)) AS Jahr,
            SUBSTR('00' || CAST(EXTRACT(WEEK FROM vorgaenge.erstelltam) AS varchar(2)), -2) AS KW
        FROM
            "rate_antraege_mit_vorgangsinfos_neuste_revision" vorgaenge
        LEFT OUTER JOIN 
            KONTOCHECKS_FINISHED k ON vorgaenge.vorgangsnummer = k.vorgangsnummer 
        WHERE
            vorgaenge.erstelltam >= CAST('2021-07-01' AS DATE)
            AND vorgaenge.erstelltam <= DATE_ADD('day', -28, current_date)
    ) AS inner_subquery 
    GROUP BY
        Jahr || '-' || KW
),  
AnzahlVorgaengeMitA2AMitSalesNachmax28Tagen AS (
    SELECT 
         Jahr || '-' || KW AS "Jahr-KW", 
        COUNT(1) AS TotalVorgaengeMitA2AMitSalesNachmax28Tagen
    FROM (
        SELECT 
            k.vorgangsnummer,
            CAST(EXTRACT(YEAR FROM sales.erstelltam) AS varchar(4)) AS Jahr,
            SUBSTR('00' || CAST(EXTRACT(WEEK FROM sales.erstelltam) AS varchar(2)), -2) AS KW
        FROM
            "rate_sales_mit_vorgangsinfos_neuste_revision" sales
        LEFT OUTER JOIN 
            KONTOCHECKS_FINISHED k ON sales.vorgangsnummer = k.vorgangsnummer 
        WHERE
            sales.erstelltam >= CAST('2021-07-01' AS DATE)
            AND sales.erstelltam <= DATE_ADD('day', -28, current_date)
            AND DATE_DIFF('day', sales.erstelltam, CAST(sales.unterschrieben_beide_zeit AS DATE)) <= 28
            AND sales.status = 'UNTERSCHRIEBEN_BEIDE'
    ) AS inner_subquery 
    GROUP BY
        Jahr || '-' || KW
)
SELECT 
    a2aVorgaenge."Jahr-KW",
    salesCount."Jahr-KW",
    a2aVorgaenge.TotalVorgangsanlagenMitA2A,
    salesCount.TotalVorgaengeMitA2AMitSalesNachmax28Tagen,
    (salesCount.TotalVorgaengeMitA2AMitSalesNachmax28Tagen * 100.0 / a2aVorgaenge.TotalVorgangsanlagenMitA2A) AS ConversionRateA2A

FROM 
    AnzahlVorgangsanlagenMitA2AKW a2aVorgaenge
LEFT JOIN 
    AnzahlVorgaengeMitA2AMitSalesNachmax28Tagen salesCount 
ON 
    a2aVorgaenge."Jahr-KW" = salesCount."Jahr-KW"
ORDER BY 
    a2aVorgaenge."Jahr-KW" DESC;