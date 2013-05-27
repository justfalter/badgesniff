cmake_minimum_required(VERSION 2.8)
PROJECT(badgesniff)

set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)


# BEGIN CONFIGURABLE STUFF
set(AVR_PROGRAMMER usbtiny
    CACHE STRING
    "programmer hardware model. See 'avrdude -c ?' for a full list."
)
set(AVRDUDE_OPTIONS CACHE STRING "additional avrdude options")

# END CONFIGURABLE STUFF

SET(THOTCON_FLASH ${CMAKE_SOURCE_DIR}/tcb.hex)

#  Hunt down AVRDUDE
find_program(AVRDUDE avrdude)
if(${AVRDUDE} STREQUAL AVRDUDE-NOTFOUND )
  message(FATAL_ERROR "Could not find avrdude")
endif()


SET(BADGE_HZ 8000000)
SET(BADGE_BAUD 38400)
SET(LFUSE "0xE2")
SET(HFUSE "0xD7")

set(MCU_TARGET atmega128rfa1)
set(AVRDUDE_TARGET atmega128rfa1)

SET(CSTANDARD "-std=gnu99")
SET(CWARN "-Wall")
SET(CTUNING "-funsigned-char -funsigned-bitfields -fpack-struct -fshort-enums")
SET(COPT "-Os")
SET(CMCU "-mmcu=${MCU_TARGET}")
SET(CDEFS "-DF_CPU=${BADGE_HZ} -DBAUD=${BADGE_BAUD}")

SET(CFLAGS "${CMCU} ${CDEFS} ${CINCS} ${COPT} ${CWARN} ${CSTANDARD}")
SET(CXXFLAGS "${CMCU} ${CDEFS} ${CINCS} ${COPT}")

SET(CMAKE_C_FLAGS ${CFLAGS})
SET(CMAKE_CXX_FLAGS ${CXXFLAGS})

INCLUDE (CheckIncludeFiles)
CHECK_INCLUDE_FILES("avr/io.h" HAVE_AVR_IO_H)
CHECK_INCLUDE_FILES("avr/interrupt.h" HAVE_AVR_INTERRUPT_H)

if(NOT HAVE_AVR_IO_H)
  message(FATAL_ERROR "Could not find avr/io.h ... Make sure you have avr-libc installed!")
endif()

if(NOT HAVE_AVR_INTERRUPT_H)
  message(FATAL_ERROR "Could not find avr/interrupt.h ... Make sure you have avr-libc installed!")
endif()

SET(ELF_FILE ${PROJECT_NAME}.elf)
SET(INTEL_HEX_FILE ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.hex)

add_executable(${ELF_FILE} ${PROJECT_NAME}.c)

add_custom_command(
  TARGET ${ELF_FILE}
    POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} 
    ARGS -j .text -j .data -O ihex ${ELF_FILE} ${INTEL_HEX_FILE}
    COMMENT "Convert ELF to IntelHEX")

add_custom_target(
  install
  COMMAND ${AVRDUDE} -p ${AVRDUDE_TARGET} -c ${AVR_PROGRAMMER} ${AVRDUDE_OPTIONS} -U flash:w:${INTEL_HEX_FILE} -U lfuse:w:${LFUSE}:m -U hfuse:w:${HFUSE}:m
  COMMAND ${CMAKE_COMMAND} -E echo "================================================================"
  COMMAND ${CMAKE_COMMAND} -E echo "NOTE: Serial interface on badge configured to run at ${BADGE_BAUD} baud!"
  COMMAND ${CMAKE_COMMAND} -E echo "================================================================"
  DEPENDS ${INTEL_HEX_FILE}
  COMMENT "Installs the badgesniff flash to the badge"
)

add_custom_target(
  restore_thotcon_flash
  COMMAND ${AVRDUDE} -p ${AVRDUDE_TARGET} -c ${AVR_PROGRAMMER} ${AVRDUDE_OPTIONS} -U flash:w:${THOTCON_FLASH}:r -U lfuse:w:0x62:m -U hfuse:w:0xd7:m -U efuse:w:0xf7:m
  COMMAND ${CMAKE_COMMAND} -E echo "================================================================"
  COMMAND ${CMAKE_COMMAND} -E echo "NOTE: The badge has been restored to the original Thotcon 0x4 firmware"
  COMMAND ${CMAKE_COMMAND} -E echo "================================================================"
  COMMENT "Restores the badge to the original Thotcon 0x4 flash image"
)
