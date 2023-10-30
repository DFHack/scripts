install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DESTINATION ${DFHACK_DATA_DESTINATION}
        FILES_MATCHING PATTERN "*.lua"
                       PATTERN "*.json"
                       PATTERN "scripts/docs" EXCLUDE
                       PATTERN "scripts/test" EXCLUDE
)

if(BUILD_TESTS)
    install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/test/
            DESTINATION ${DFHACK_DATA_DESTINATION}/scripts/test/scripts
    )
endif()
