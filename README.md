# Cursoteca

**Cursoteca** es un archivo histórico colaborativo de materiales académicos de la Escuela de Ciencias de la Computación e Informática (UCR), gestionado por la Asociación de Estudiantes (AECCI). Su propósito es centralizar recursos de cursos anteriores (cartas al estudiante, diapositivas, enunciados de exámenes) para la consulta abierta de la comunidad estudiantil.

Este es un nombre que se me ocurrió para el proyecto, pero es completamente intercambiable. Si hay alguna otra sugerencia, estoy abierto a ideas.

## Arquitectura

El proyecto se despliega utilizando **Docker** y se divide en dos servicios principales que interactúan con un volumen de almacenamiento compartido (`/data`):

*   **Frontend Público (Caddy):** Servidor web que expone el sitio web estático y un directorio navegable de los cursos estrictamente de **solo lectura**.
*   **Backend de Administración (FileBrowser):** Interfaz web autenticada utilizada por profesores y curadores para subir, organizar y gestionar el material didáctico.
*   **Automatización:** Scripts en Bash ejecutados mediante `cron` para calcular estadísticas de uso y almacenamiento (`stats.json`).

## Estructura de Almacenamiento

Los archivos se organizan siguiendo el avance natural de la carrera:

```text
data/
└── Año_1/
    └── Ciclo_2/
        └── Programacion_I_CI0112/
            └── 2025_Semestre_I/
                ├── Carta_al_Estudiante.pdf
                ├── 01_Material/
                ├── 02_Quices/
                └── 03_Examenes_Enunciados/
```

## 🚀 Despliegue Local

La infraestructura está definida en `config/docker-compose.yml`. Para levantar los servicios:

```bash
cd config
sudo docker compose up -d
```