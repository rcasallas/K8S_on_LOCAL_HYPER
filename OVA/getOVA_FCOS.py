import requests
import shutil
import os

def descargar_fcos_ova(platform="virtualbox"):

    # Obtiene la ruta completa del archivo actual
    ruta_completa = os.path.abspath(__file__)
    # Obtiene solo la carpeta donde está el archivo
    directorio = os.path.dirname(ruta_completa)
    
    # 1. Obtener la URL
    metadata_url = "https://builds.coreos.fedoraproject.org/streams/stable.json"
    data = requests.get(metadata_url).json()

    ova_url = data['architectures']['x86_64']['artifacts'][platform]['formats']['ova']['disk']['location']
    filename = ova_url.split("/")[-1]

    print(f"Descargando {filename}...")

    # 2. Realizar la descarga en modo stream (para archivos grandes)
    with requests.get(ova_url, stream=True) as r:
        with open(directorio+"/"+filename, 'wb') as f:
            shutil.copyfileobj(r.raw, f)
            
    print("¡Descarga completada!")

descargar_fcos_ova("virtualbox")