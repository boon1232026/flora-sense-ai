# FLORA SENSE AI repository notes

## Verification commands

- Backend: `make -C backend test`
- AI engine: `cd ai-engine && python3 -m unittest discover -s tests -v`
- Flutter: `cd mobile-app && flutter analyze && flutter test`
- ESP-IDF: `cd firmware && idf.py set-target esp32s3 && idf.py build`

## Boundaries

- Keep credentials out of source. Use `.env.example` as the template only.
- AI must not control a pump directly; commands go through the C backend and firmware safety controller.
- Keep MQTT pump commands non-retained, UUID-keyed and expiring.
- Do not hardcode final GPIO choices until the selected ESP32-S3 board and pump driver are confirmed.
- Sensor readings are UTC; UI displays local timezone.
- Store image files in object storage and database rows contain only path/metadata.
