-- Labs query
-- Created 2020-04-30

SELECT
m.mrn,
en.encounter AS csn,
result_datetime.value_as_datetime AS result_datetime,
battery_code.value_as_string AS battery_code,
local_code.value_as_string AS local_code,
c.concept_name AS mapped_name,
result.value_as_string AS result_text,
ref_range.value_as_string AS reference_range
FROM ((((((((((((star_validation.patient_fact pf
                 LEFT JOIN star_validation.patient_property battery_code
                 ON (((battery_code.fact = pf.patient_fact_id)
                      AND (battery_code.property_type = (SELECT
                                                         attribute.attribute_id
                                                         FROM star_validation.attribute
                                                         WHERE ((attribute.short_name) :: TEXT = 'PATH_BATT_COD' :: TEXT))
                      )
                      AND (battery_code.valid_until IS NULL)
                      AND (battery_code.stored_until IS NULL))))
                LEFT JOIN star_validation.patient_property local_code
                ON (((local_code.fact = pf.patient_fact_id)
                     AND (local_code.property_type = (SELECT
                                                      attribute.attribute_id
                                                      FROM star_validation.attribute
                                                      WHERE ((attribute.short_name) :: TEXT = 'PATH_TEST_COD' :: TEXT))
                     )
                     AND (local_code.valid_until IS NULL)
                     AND (local_code.stored_until IS NULL))))
               LEFT JOIN star_validation.patient_property result
               ON (((result.fact = pf.patient_fact_id)
                    AND (result.property_type = (SELECT
                                                 attribute.attribute_id
                                                 FROM star_validation.attribute
                                                 WHERE ((attribute.short_name) :: TEXT = 'PATH_NUM_VALUE' :: TEXT))
                    )
                    AND (result.valid_until IS NULL)
                    AND (result.stored_until IS NULL))))
              LEFT JOIN star_validation.patient_property result_datetime
              ON (((pf.patient_fact_id = result_datetime.fact)
                   AND (result_datetime.property_type = (SELECT
                                                         attribute.attribute_id
                                                         FROM star_validation.attribute
                                                         WHERE ((attribute.short_name) :: TEXT = 'PATH_RES_TIME' :: TEXT))
                   )
                   AND (result_datetime.valid_until IS NULL)
                   AND (result_datetime.stored_until IS NULL))))
             LEFT JOIN star_validation.patient_property ref_range
             ON (((pf.patient_fact_id = ref_range.fact)
                  AND (ref_range.property_type = (SELECT
                                                  attribute.attribute_id
                                                  FROM star_validation.attribute
                                                  WHERE ((attribute.short_name) :: TEXT = 'PATH_REF_RANGE' :: TEXT))
                  )
                  AND (ref_range.valid_until IS NULL)
                  AND (ref_range.stored_until IS NULL))))
            JOIN star_validation.encounter en
            ON ((pf.encounter = en.encounter_id)))
           LEFT JOIN star_validation.mrn_encounter me
           ON (((en.encounter_id = me.encounter)
                AND (me.stored_until IS NULL)
                AND (me.valid_until IS NULL))))
          LEFT JOIN star_validation.person_mrn pm
          ON (((pm.mrn = me.mrn)
               AND (pm.stored_until IS NULL)
               AND (pm.valid_until IS NULL))))
         LEFT JOIN star_validation.person_mrn pm1
         ON (((pm1.person = pm.person)
              AND pm1.live
              AND (pm1.stored_until IS NULL)
              AND (pm1.valid_until IS NULL))))
        LEFT JOIN star_validation.mrn m
        ON ((pm1.mrn = m.mrn_id)))
       LEFT JOIN ops_validation.etl_labs_metadata elm
       ON ((local_code.value_as_string = (elm.test_code) :: TEXT)))
      LEFT JOIN ops.concept c
      ON (((elm.omop_code) :: INTEGER = c.concept_id)))
WHERE ((pf.fact_type = (SELECT
                        attribute.attribute_id
                        FROM star_validation.attribute
                        WHERE ((attribute.short_name) :: TEXT = 'PATH_RESULT' :: TEXT))
)
AND (pf.valid_until IS NULL)
AND (pf.stored_until IS NULL));

