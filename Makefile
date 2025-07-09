####
# Written by h0ffy // JennyLab
####

CC = gcc

UPDATE_SUBMODULES := $(shell git submodule update --init --recursive)

TARGET = libdensity
# CFLAGS para compilación: optimizaciones, estándar C99, advertencias, generación de dependencias,
# -fPIC para código independiente de la posición (necesario para librerías compartidas),
# -msse2 para optimizaciones específicas de SSE2.
CFLAGS = -Ofast -flto -std=c99 -Wall -MD -fPIC -msse2
# LFLAGS para enlazado: optimización LTO, y -lm para enlazar con la librería matemática.
LFLAGS = -flto -lm

BUILD_DIRECTORY = build
DENSITY_BUILD_DIRECTORY = $(BUILD_DIRECTORY)/density
SRC_DIRECTORY = src

# Lista explícita de archivos fuente para la librería, según lo solicitado para el 'wrapping' de Python.
DENSITY_SRC = \
	src/globals.c \
	src/algorithms/algorithms.c \
	src/algorithms/chameleon/core/chameleon_encode.c \
	src/algorithms/chameleon/core/chameleon_decode.c \
	src/algorithms/cheetah/core/cheetah_encode.c \
	src/algorithms/cheetah/core/cheetah_decode.c \
	src/algorithms/lion/core/lion_encode.c \
	src/algorithms/lion/core/lion_decode.c \
	src/algorithms/lion/forms/lion_form_model.c \
	src/structure/header.c \
	src/buffers/buffer.c \
	src/algorithms/dictionaries.c

# Genera los nombres de los archivos objeto a partir de los archivos fuente,
# manteniendo la estructura de directorios dentro de BUILD_DIRECTORY.
DENSITY_OBJ = $(patsubst $(SRC_DIRECTORY)/%.c, $(DENSITY_BUILD_DIRECTORY)/%.o, $(DENSITY_SRC))

# Determinación del sistema operativo y arquitectura para flags adicionales.
TARGET_TRIPLE := $(subst -, ,$(shell $(CC) -dumpmachine))
TARGET_ARCH   := $(word 1,$(TARGET_TRIPLE))
TARGET_OS     := $(word 3,$(TARGET_TRIPLE))

# Las flags -fpic/-fPIC ya se incluyen en CFLAGS de forma incondicional para el 'wrapping' de Python.
# Este bloque se mantiene por si hubiera otras flags específicas de OS que no sean -fpic.
ifeq ($(TARGET_OS),mingw32)
else ifeq ($(TARGET_OS),cygwin)
else
	# CFLAGS += -fpic # Ya incluido en CFLAGS globalmente
endif

# Flags de arquitectura (32/64 bits).
ifeq ($(ARCH),)
	ifeq ($(NATIVE),)
		ifeq ($(TARGET_ARCH),powerpc)
			CFLAGS += -mtune=native
		else
			CFLAGS += -march=native
		endif
	endif
else
	ifeq ($(ARCH),32)
		CFLAGS += -m32
		LFLAGS += -m32
	endif

	ifeq ($(ARCH),64)
		CFLAGS += -m64
		LFLAGS += -m64
	endif
endif

# Configuración de variables para diferentes sistemas operativos (Windows/Linux/macOS).
ifeq ($(OS),Windows_NT)
	bold =
	normal =
	ARROW = ^-^>
	EXTENSION = .dll
	BENCHMARK_EXTENSION = .exe
	SEPARATOR = \\
else
	bold = `tput bold`
	normal = `tput sgr0`
	ARROW = \-\>
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Darwin)
		EXTENSION = .dylib
	else
		EXTENSION = .so
	endif
	BENCHMARK_EXTENSION =
	SEPARATOR = /
	# Desactivar _FORTIFY_SOURCE en Ubuntu si está presente.
	ifeq ($(shell lsb_release -a 2>/dev/null | grep Distributor | awk '{ print $$3 }'),Ubuntu)
		CFLAGS += -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0
	endif
endif
STATIC_EXTENSION = .a

# Archivos de dependencia generados por -MD.
DEPS=$(wildcard *.d)

.PHONY: pre-compile post-compile pre-link post-link library benchmark all clean

# Objetivo por defecto.
all: benchmark

# Regla para compilar archivos .c a .o.
$(DENSITY_BUILD_DIRECTORY)/%.o: $(SRC_DIRECTORY)/%.c
	@mkdir -p "$(@D)"
	$(CC) $(CFLAGS) -c $< -o $@

# Mensaje antes de la compilación.
pre-compile:
	@echo ${bold}Compiling Density${normal} ...

# Compila todos los archivos fuente a objetos.
compile: pre-compile $(DENSITY_OBJ)

# Mensaje después de la compilación.
post-compile: compile
	@echo Done.
	@echo

# Mensaje antes del enlazado.
pre-link : post-compile
	@echo ${bold}Linking Density as a library${normal} ...

# Enlaza los archivos objeto para crear la librería estática y dinámica.
link: pre-link $(DENSITY_OBJ)
	# Crea la librería estática.
	$(AR) crs $(BUILD_DIRECTORY)/$(TARGET)$(STATIC_EXTENSION) $(DENSITY_OBJ)
	# Crea la librería dinámica.
	$(CC) $(LFLAGS) -shared -o $(BUILD_DIRECTORY)/$(TARGET)$(EXTENSION) $(DENSITY_OBJ)

# Mensaje después del enlazado y muestra las rutas de las librerías.
post-link: link
	@echo Done.
	@echo
	@echo Static library file : ${bold}$(BUILD_DIRECTORY)$(SEPARATOR)$(TARGET)$(STATIC_EXTENSION)${normal}
	@echo Dynamic library file : ${bold}$(BUILD_DIRECTORY)$(SEPARATOR)$(TARGET)$(EXTENSION)${normal}
	@echo

# Dependencia para asegurar que la librería dinámica se construye.
$(BUILD_DIRECTORY)/$(TARGET)$(EXTENSION): post-link

# Objetivo para construir solo la librería.
library: post-link

# Objetivo para construir la librería y luego el benchmark.
benchmark: library
	@$(MAKE) -C benchmark/
	@echo Please type ${bold}$(BUILD_DIRECTORY)$(SEPARATOR)benchmark$(BENCHMARK_EXTENSION)${normal} to launch the benchmark binary.
	@echo

# Objetivo para limpiar todos los archivos generados.
clean:
	@$(MAKE) -C benchmark/ clean
	@echo ${bold}Cleaning Density build files${normal} ...
	@rm -f $(DENSITY_OBJ)
	@rm -f $(BUILD_DIRECTORY)/$(TARGET)$(EXTENSION)
	@rm -f $(BUILD_DIRECTORY)/$(TARGET)$(STATIC_EXTENSION)
	@rm -f $(DEPS)
	@echo Done.
	@echo

# Incluye los archivos de dependencia generados automáticamente.
-include $(DENSITY_OBJ:.o=.d)
