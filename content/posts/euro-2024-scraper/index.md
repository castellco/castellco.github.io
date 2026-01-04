---
title: "Web Scraping de la EURO 2024 con Python"
date: 2025-12-31T10:30:00+01:00
draft: false
summary: "Tutorial de web scraping en Python para recolectar las estadísticas de los jugadores de la Euro 2024."
tags: ["web scraping","fútbol","python"]
---

![showcase](https://raw.githubusercontent.com/castellco/euro_2024_scraper/main/showcase.gif)

En este post explicaré cómo construí un scraper en Python para recolectar las estadísticas de los jugadores de la Euro 2024 desde la web oficial de la UEFA.

## Motivación

Entre junio y julio del 2024 tuvo lugar la EURO 2024. En ese contexto, participé de un reto del chapter local de [Omdena](https://www.omdena.com/) en Tunisia para aprender en la práctica a analizar datos de fútbol. Lo quise aprender porque me gusta el fútbol: antes jugarlo y ahora verlo. Sin embargo, en las primeras reuniones virtuales un problema surgió: no teníamos datos. 

Así, varios colegas nos dispusimos a buscar o crear datasets diversos: estadísticas de cada partido, datasets históricos o lo que haya. Cuando visité la página de la [EURO](https://www.uefa.com/european-qualifiers/statistics/players/), vi que era posible y me propuse la tarea de proveer al equipo de un dataset con las estadísticas de los jugadores.

A modo de documentación de ese ejercicio, en este post resumo la lógica detrás del scraper en Python + Selenium que hice y que extrae las estadísticas de jugadores desde la web de la UEFA y las prepara en un `pandas.DataFrame` para análisis exploratorio y modelado.


## Resumen técnico

El objetivo principal es automatizar la recolección de datos de los jugadores de la [EURO](https://www.uefa.com/european-qualifiers/statistics/players/) a falta de acceso a API oficial. El output debía ser un dataset en formato tabular.

Usé Python por ser el lenguaje de preferencia en los proyectos de Omdena en los que he participado, aunque R hubiera servido también.

En específico, el scraper implementa:
- Selenium, para renderizar y leer tablas dinámicas en la página de estadísticas de la UEFA.
- Los registros se transforman a `pandas.DataFrame`; el autor deja la data en memoria, pero es trivial exportarla a CSV/JSON.
- Incluye utilidades para limpieza y normalización de nombres y un Jupyter Notebook con ejemplos de análisis.

**Cómo ejecutar (rápido)**

1. Asegúrate de tener Chrome actualizado.
2. Instala dependencias:

```bash
pip install selenium pandas
```

3. Ejecuta el scrapper (el script suele gestionar el webdriver):

```bash
python scrapers/euro2024.py
```

4. Carga los resultados para inspección:

```py
import pandas as pd
df = pd.read_json('data/euro2024/players.json')
df.head()
```

**Consideraciones**

- Mantén Chrome/Chromedriver sincronizados.
- Respeta las políticas del sitio y añade pausas para evitar sobrecarga.
- Para reproducibilidad, guarda los dumps generados junto al código.

**Usos propuestos**

- Calcular métricas por 90 minutos y comparar entre competiciones.
- Entrenar modelos que predigan probabilidad de gol o rendimiento futuro.
- Construir dashboards interactivos por jugador o selección.

**Código**

Repositorio: https://github.com/castellco/euro_2024_scraper

Puedo, si quieres, exportar un CSV de ejemplo desde ese repo, incrustar la imagen local en la entrada, o añadir fragmentos del notebook.


