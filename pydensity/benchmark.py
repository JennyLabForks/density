#####
#  Written by h0ffy // JennyLAb
#####

import ctypes
import sys
import time
import os

# Cargar la biblioteca compartida
try:
    density = ctypes.CDLL('./libdensity.so')
except OSError:
    print("Error: No se pudo cargar la biblioteca libdensity.so.")
    print("Por favor, compile la biblioteca compartida primero usando 'make'.")
    sys.exit(1)

# Definir los tipos de datos de la API de C
class DensityProcessingResult(ctypes.Structure):
    _fields_ = [
        ("state", ctypes.c_int),
        ("bytesRead", ctypes.c_uint64),
        ("bytesWritten", ctypes.c_uint64),
        ("context", ctypes.c_void_p)
    ]

# Definir los algoritmos de compresión
DENSITY_ALGORITHM_CHAMELEON = 1
DENSITY_ALGORITHM_CHEETAH = 2
DENSITY_ALGORITHM_LION = 3

# Definir los argumentos y tipos de retorno para las funciones de C
density.density_version_major.restype = ctypes.c_uint8
density.density_version_minor.restype = ctypes.c_uint8
density.density_version_revision.restype = ctypes.c_uint8

density.density_compress_safe_size.argtypes = [ctypes.c_uint64]
density.density_compress_safe_size.restype = ctypes.c_uint64

density.density_decompress_safe_size.argtypes = [ctypes.c_uint64]
density.density_decompress_safe_size.restype = ctypes.c_uint64

density.density_compress.argtypes = [ctypes.c_void_p, ctypes.c_uint64, ctypes.c_void_p, ctypes.c_uint64, ctypes.c_int]
density.density_compress.restype = DensityProcessingResult

density.density_decompress.argtypes = [ctypes.c_void_p, ctypes.c_uint64, ctypes.c_void_p, ctypes.c_uint64]
density.density_decompress.restype = DensityProcessingResult


def benchmark_version():
    print(f"\nBenchmark en memoria de subproceso único impulsado por Centaurean Density {density.density_version_major()}.{density.density_version_minor()}.{density.density_version_revision()}")

def client_usage():
    print("\nUso:")
    print("  python wrapper.py [OPCIONES?...] [ARCHIVO?]")
    print("\nOpciones disponibles:")
    print("  -[NIVEL]                          Prueba el archivo usando solo el NIVEL de compresión especificado.")
    print("                                    Si no se especifica, se prueban todos los algoritmos (predeterminado).")
    print("                                    NIVEL puede tener los siguientes valores:")
    print("                                    1 = Algoritmo Chameleon")
    print("                                    2 = Algoritmo Cheetah")
    print("                                    3 = Algoritmo Lion")
    print("  -c                                Comprimir solo")
    sys.exit(0)

def main():
    benchmark_version()
    start_mode = DENSITY_ALGORITHM_CHAMELEON
    end_mode = DENSITY_ALGORITHM_LION
    compression_only = False
    file_path = None

    if len(sys.argv) <= 1:
        client_usage()

    for arg in sys.argv[1:]:
        if arg.startswith('-'):
            if arg[1] == '1':
                start_mode = DENSITY_ALGORITHM_CHAMELEON
                end_mode = DENSITY_ALGORITHM_CHAMELEON
            elif arg[1] == '2':
                start_mode = DENSITY_ALGORITHM_CHEETAH
                end_mode = DENSITY_ALGORITHM_CHEETAH
            elif arg[1] == '3':
                start_mode = DENSITY_ALGORITHM_LION
                end_mode = DENSITY_ALGORITHM_LION
            elif arg[1] == 'c':
                compression_only = True
            else:
                client_usage()
        else:
            file_path = arg

    if not file_path:
        print("\nError: La ruta del archivo es obligatoria.")
        client_usage()

    try:
        with open(file_path, 'rb') as f:
            in_data = f.read()
    except FileNotFoundError:
        print(f"\nError: No se pudo abrir el archivo {file_path}.")
        sys.exit(1)

    uncompressed_size = len(in_data)
    compress_safe_size = density.density_compress_safe_size(uncompressed_size)

    in_buffer = ctypes.create_string_buffer(in_data)
    out_buffer = ctypes.create_string_buffer(compress_safe_size)

    print(f"Espacio de trabajo en memoria asignado: {compress_safe_size * 2} bytes")

    for compression_mode in range(start_mode, end_mode + 1):
        if compression_mode == DENSITY_ALGORITHM_CHAMELEON:
            print("\nAlgoritmo Chameleon")
            print("="*19)
        elif compression_mode == DENSITY_ALGORITHM_CHEETAH:
            print("\nAlgoritmo Cheetah")
            print("="*17)
        elif compression_mode == DENSITY_ALGORITHM_LION:
            print("\nAlgoritmo Lion")
            print("="*14)

        print(f"Usando el archivo '{file_path}' copiado en memoria")

        # Compresión
        start_time = time.process_time()
        compress_result = density.density_compress(in_buffer, uncompressed_size, out_buffer, compress_safe_size, compression_mode)
        compress_time = time.process_time() - start_time

        if compress_result.state != 0:
            print(f"Error durante la compresión: {compress_result.state}")
            continue

        compressed_size = compress_result.bytesWritten
        compress_speed = uncompressed_size / compress_time / (1024 * 1024) if compress_time > 0 else float('inf')

        print(f"Compresión: {uncompressed_size} -> {compressed_size} bytes en {compress_time:.4f}s ({compress_speed:.2f} MB/s)")
        print(f"Ratio de compresión: {compressed_size / uncompressed_size:.2%}")

        if not compression_only:
            # Descompresión
            decompressed_buffer = ctypes.create_string_buffer(uncompressed_size)
            start_time = time.process_time()
            decompress_result = density.density_decompress(out_buffer, compressed_size, decompressed_buffer, uncompressed_size)
            decompress_time = time.process_time() - start_time

            if decompress_result.state != 0:
                print(f"Error durante la descompresión: {decompress_result.state}")
                continue

            decompress_speed = uncompressed_size / decompress_time / (1024 * 1024) if decompress_time > 0 else float('inf')
            print(f"Descompresión: {compressed_size} -> {decompress_result.bytesWritten} bytes en {decompress_time:.4f}s ({decompress_speed:.2f} MB/s)")

            # Verificación
            if decompressed_buffer.raw != in_buffer.raw:
                print("Error: Los datos descomprimidos no coinciden con los datos originales.")
            else:
                print("Verificación correcta.")

if __name__ == "__main__":
    main()
