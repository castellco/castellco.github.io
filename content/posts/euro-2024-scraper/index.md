---
title: "Euro 2024 — Scraper de resultados y estadísticas"
date: 2025-12-31T10:30:00+01:00
draft: false
summary: "Scraper y pipeline para recolectar resultados, alinearlos y publicar estadísticas en tiempo diferido."
tags: ["scraper","deportes","estadísticas"]
---

Descripción: pipeline para extraer resultados de partidos, normalizar equipos y calcular métricas agregadas.

Componentes:

- `scrapers/euro2024.py` — extracción y guardado en CSV/JSON.
- `notebooks/stats.ipynb` — cálculos y visualizaciones.

Cómo ejecutar:

1. Instalar dependencias: `pip install -r requirements.txt`.
2. Ejecutar `python scrapers/euro2024.py` para generar `data/euro2024/*.json`.

Resultados clave y hallazgos resumidos en la sección final.

