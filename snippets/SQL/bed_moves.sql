-- Bed moves query
-- Created 2020-04-30
SELECT
  m.mrn,
  en.encounter AS csn,
  admit.value_as_datetime AS admission,
  disch.value_as_datetime AS discharge,
  dep.epicdepartmentname AS department,
  room.roomname AS room,
  bed."BedLabel(InterfaceId)" AS bed,
  loc.value_as_string AS hl7_location
FROM (((((((((((star.patient_fact pf
  LEFT JOIN star.patient_property loc
    ON (((loc.fact = pf.patient_fact_id)
    AND (loc.property_type = (SELECT
        att.attribute_id
      FROM star.attribute att
      WHERE ((att.short_name) :: TEXT = 'LOCATION' :: TEXT))
    )
    AND (loc.stored_until IS NULL)
    AND (loc.valid_until IS NULL))))
  LEFT JOIN star.patient_property admit
    ON (((admit.fact = pf.patient_fact_id)
    AND (admit.property_type = (SELECT
        att.attribute_id
      FROM star.attribute att
      WHERE ((att.short_name) :: TEXT = 'ARRIVAL_TIME' :: TEXT))
    )
    AND (admit.stored_until IS NULL)
    AND (admit.valid_until IS NULL))))
  LEFT JOIN star.patient_property disch
    ON (((disch.fact = pf.patient_fact_id)
    AND (disch.property_type = (SELECT
        att.attribute_id
      FROM star.attribute att
      WHERE ((att.short_name) :: TEXT = 'DISCH_TIME' :: TEXT))
    )
    AND (disch.stored_until IS NULL)
    AND (disch.valid_until IS NULL))))
  LEFT JOIN star.encounter en
    ON ((pf.encounter = en.encounter_id)))
  LEFT JOIN star.mrn_encounter me
    ON (((en.encounter_id = me.encounter)
    AND (me.stored_until IS NULL)
    AND (me.valid_until IS NULL))))
  LEFT JOIN star.person_mrn pm
    ON (((pm.mrn = me.mrn)
    AND (pm.stored_until IS NULL)
    AND (pm.valid_until IS NULL))))
  LEFT JOIN star.person_mrn pm1
    ON (((pm1.person = pm.person)
    AND pm1.live
    AND (pm1.stored_until IS NULL)
    AND (pm1.valid_until IS NULL))))
  LEFT JOIN star.mrn m
    ON ((pm1.mrn = m.mrn_id)))
  LEFT JOIN (SELECT DISTINCT ON (
      locations."EpicDepartmentMpiId(InterfaceId)")
      locations."EpicDepartmentMpiId(InterfaceId)",
      locations.epicdepartmentname
    FROM covid_staging.locations
    ORDER BY locations."EpicDepartmentMpiId(InterfaceId)", COALESCE(locations.departmentrecordstatusid, '0' :: CHARACTER VARYING))
  dep
    ON (((dep."EpicDepartmentMpiId(InterfaceId)") :: TEXT = NULLIF(SPLIT_PART(loc.value_as_string, '^' :: TEXT, 1), 'null' :: TEXT))))
  LEFT JOIN (SELECT DISTINCT ON (
      locations."EpicDepartmentMpiId(InterfaceId)",
      locations."RoomExternalId(InterfaceId)")
      locations."EpicDepartmentMpiId(InterfaceId)",
      locations."RoomExternalId(InterfaceId)",
      locations.epicdepartmentname,
      locations.roomname
    FROM covid_staging.locations
    ORDER BY locations."EpicDepartmentMpiId(InterfaceId)", locations."RoomExternalId(InterfaceId)", COALESCE(locations.departmentrecordstatusid, '0' :: CHARACTER VARYING))
  room
    ON ((((room."EpicDepartmentMpiId(InterfaceId)") :: TEXT = NULLIF(SPLIT_PART(loc.value_as_string, '^' :: TEXT, 1), 'null' :: TEXT))
    AND ((room."RoomExternalId(InterfaceId)") :: TEXT = NULLIF(SPLIT_PART(loc.value_as_string, '^' :: TEXT, 2), 'null' :: TEXT)))))
  LEFT JOIN (SELECT DISTINCT ON (
      locations."EpicDepartmentMpiId(InterfaceId)",
      locations."RoomExternalId(InterfaceId)",
      locations."BedLabel(InterfaceId)")
      locations."EpicDepartmentMpiId(InterfaceId)",
      locations."RoomExternalId(InterfaceId)",
      locations."BedLabel(InterfaceId)",
      locations.epicdepartmentname,
      locations.roomname
    FROM covid_staging.locations
    ORDER BY locations."EpicDepartmentMpiId(InterfaceId)", locations."RoomExternalId(InterfaceId)", locations."BedLabel(InterfaceId)", COALESCE(locations.departmentrecordstatusid, '0' :: CHARACTER VARYING))
  bed
    ON ((((bed."EpicDepartmentMpiId(InterfaceId)") :: TEXT = NULLIF(SPLIT_PART(loc.value_as_string, '^' :: TEXT, 1), 'null' :: TEXT))
    AND ((bed."RoomExternalId(InterfaceId)") :: TEXT = NULLIF(SPLIT_PART(loc.value_as_string, '^' :: TEXT, 2), 'null' :: TEXT))
    AND ((bed."BedLabel(InterfaceId)") :: TEXT = NULLIF(SPLIT_PART(loc.value_as_string, '^' :: TEXT, 3), 'null' :: TEXT)))))
WHERE ((pf.fact_type = (SELECT
    att.attribute_id
  FROM star.attribute att
  WHERE ((att.short_name) :: TEXT = 'BED_VISIT' :: TEXT))
)
AND (pf.stored_until IS NULL)
AND (pf.valid_until IS NULL));

