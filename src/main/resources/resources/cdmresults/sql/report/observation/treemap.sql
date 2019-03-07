SELECT
  concept_hierarchy.concept_id                          AS concept_id,
  CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(
    isNull(concept_hierarchy.level3_concept_name, 'NA'), '||'),
    isNull(concept_hierarchy.level2_concept_name, 'NA')), '||'),
    isNull(concept_hierarchy.level1_concept_name, 'NA')), '||'),
    isNull(concept_hierarchy.concept_name, 'NA'))       AS concept_path,
  ar1.count_value                                       AS num_persons,
  1.0 * ar1.count_value / denom.count_value             AS percent_persons,
  1.0 * ar2.count_value / ar1.count_value               AS records_per_person
FROM (SELECT *
      FROM @results_database_schema.ACHILLES_results WHERE analysis_id = 800) ar1
  INNER JOIN
  (SELECT *
   FROM @results_database_schema.ACHILLES_results WHERE analysis_id = 801) ar2
    ON ar1.stratum_1 = ar2.stratum_1
  INNER JOIN
  @results_database_schema.concept_hierarchy concept_hierarchy
  ON CAST(CASE WHEN isNumeric(ar1.stratum_1) = 1 THEN ar1.stratum_1 ELSE null END AS INT) = concept_hierarchy.concept_id
  AND concept_hierarchy.treemap='Observation'
  ,
  (SELECT count_value
   FROM @results_database_schema.ACHILLES_results WHERE analysis_id = 1) denom
ORDER BY ar1.count_value DESC
