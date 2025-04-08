WITH KONTOCHECKS_NOT_FINISHED AS (
    SELECT 
        ereignis.vorgangsnummer
    FROM 
        "prod_rate_consumable"."rate_vorgang_neueste_ereignis_mit_betreuer_id" ereignis
    WHERE 
        ereignis."ereignistype"!= 'kontocheck-finished'
),
AnzahlVorgangsanlagenOhneA2AKW AS (
    SELECT
        Jahr || '-' || KW AS "Jahr-KW", 
        COUNT(1) AS AnzahlVorgangsanlagenOhneA2A 
    FROM (
        SELECT 
            keinkontocheck.vorgangsnummer,
            CAST(EXTRACT(YEAR FROM vorgaenge.erstelltam) AS varchar(4)) AS Jahr,
            SUBSTR('00' || CAST(EXTRACT(WEEK FROM vorgaenge.erstelltam) AS varchar(2)), -2) AS KW
        FROM
            "rate_antraege_mit_vorgangsinfos_neuste_revision" vorgaenge
        LEFT OUTER JOIN 
            KONTOCHECKS_NOT_FINISHED keinkontocheck ON vorgaenge.vorgangsnummer = keinkontocheck.vorgangsnummer 
        WHERE
            vorgaenge.erstelltam >= CAST('2021-07-01' AS DATE)
            AND vorgaenge.erstelltam <= DATE_ADD('day', -28, current_date)
    ) AS inner_subquery 
    GROUP BY
        Jahr || '-' || KW
),
AnzahlVorgaengeOhneA2AMitSalesNachmax28Tagen AS (
    SELECT 
         Jahr || '-' || KW AS "Jahr-KW", 
        COUNT(1) AS AnzahlVorgaengeOhneA2AMitSalesNachmax28Tagen
    FROM (
        SELECT 
            keinkontocheck.vorgangsnummer,
            CAST(EXTRACT(YEAR FROM sales.erstelltam) AS varchar(4)) AS Jahr,
            SUBSTR('00' || CAST(EXTRACT(WEEK FROM sales.erstelltam) AS varchar(2)), -2) AS KW
        FROM
            "rate_sales_mit_vorgangsinfos_neuste_revision" sales
        LEFT OUTER JOIN 
            KONTOCHECKS_NOT_FINISHED keinkontocheck ON sales.vorgangsnummer = keinkontocheck.vorgangsnummer 
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
    
    keinA2AVorgaenge."Jahr-KW",
    keinA2ASalesCount."Jahr-KW",
    keinA2AVorgaenge.AnzahlVorgangsanlagenOhneA2A,
    keinA2ASalesCount.AnzahlVorgaengeOhneA2AMitSalesNachmax28Tagen,
    (keinA2ASalesCount.AnzahlVorgaengeOhneA2AMitSalesNachmax28Tagen * 100.0 / keinA2AVorgaenge.AnzahlVorgangsanlagenOhneA2A) AS ConversionRateOhneA2A
    
FROM 
    AnzahlVorgangsanlagenOhneA2AKW keinA2AVorgaenge

LEFT JOIN 
    AnzahlVorgaengeOhneA2AMitSalesNachmax28Tagen keinA2ASalesCount ON keinA2AVorgaenge."Jahr-KW" = keinA2ASalesCount."Jahr-KW"
ORDER BY 
    keinA2ASalesCount."Jahr-KW" DESC;