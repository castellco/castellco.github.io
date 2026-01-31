---
title: "La geografía del terrorismo"
date: 2025-02-07T10:00:00+01:00
draft: false
summary: "Análisis espacial de incidentes y patrones de violencia en Perú usando datos públicos."
tags: ["datos espaciales","Perú","GIS", "R"]
featureimage: "https://raw.githubusercontent.com/castellco/terrorism_peru/refs/heads/main/figs/map_full.png"
---

Este post es sobre el TFM con el que me gradué del Máster Universitario en Ciencias Sociales Computacionales en la UC3M. Para este, apliqué modelos espaciales para estudiar la difusión de ataques terroristas en Perú durante la temporada álgida del Conflicto Armado Interno (1980-2000) y desde entonces a la actualidad, comparando diferentes períodos temporales y técnicas de modelado.

El código es open source en Github:
{{< github repo="castellco/terrorism_peru" >}}

## ¿Por qué modelos espaciales? El problema de la dependencia espacial

Los métodos tradicionales de regresión (OLS) asumen que las observaciones son **independientes entre sí**. Sin embargo, en fenómenos espaciales como los ataques terroristas, esta suposición se viola sistemáticamente.

> “Todo está relacionado con todo lo demás, pero las cosas cercanas están más relacionadas que las distantes.”  
> — <cite> Waldo Tobler (1970)</cite>

Esta, la llamada "Primera ley de Tobler", es la madre de varios conceptos clave en análisis espacial. En específico, en mi TFM refiero mucho a la **autocorrelación espacial**, que describe cómo las observaciones en ubicaciones geográficas cercanas tienden a ser más similares entre sí que las distantes. Ignorar esta dependencia lleva a estimaciones sesgadas de los efectos, errores estándar incorrectos (generalmente subestimados), e inferencias inválidas. Por eso, si quería estudiar la territorialidad del Conflicto Armado Interno, debían usar modelos espaciales.

## Metodología

Siguiendo las recomendaciones de Buhaug y Rød (2006), utilicé **celdas de grilla (grid cells)**, en este caso de 0.5 × 0.5 grados decimales como unidades de análisis en lugar de divisiones administrativas tradicionales, como distritos o provincias.

Este enfoque tiene ventajas, como que las celdas no cambian en tamaño, forma o número a lo largo del tiempo, permiten controlar mejor por decisiones políticas que podrían afectar la frecuencia de eventos, constituyen entidades inherentemente apolíticas (Tollefsen et al., 2012), entre otros.

![Grid cells sobre territorio peruano](https://raw.githubusercontent.com/castellco/terrorism_peru/refs/heads/main/figs/map_grids.png)


### Los datos

Integré datos de múltiples fuentes georreferenciadas:

1. **[Global Terrorism Database (GTD)](https://www.start.umd.edu/data-tools/GTD)**: Mi principal dataset, que contiene información de ~200,000 incidentes terroristas a nivel global (1970-2021)
2. **[PRIO-GRID](https://grid.prio.org/#/download)**: Una base de variables geodemográficas a nivel de celda 0.5×0.5
3. **[xSUB](https://cross-sub.org/)**: Datos subnacionales de conflicto compatibles con PRIO-GRID
4. **Shapefiles**: Geometrías de celdas mundiales y fronteras de Perú

### El procesamiento
Básicamente, y para resumir, hice un *point-in-polygon spatial join* para asignar los ataques (los puntos) a los grid cells (los polígonos). Luego, construí tres sub datasets temporales: uno para el pico de la violencia (1980-2000), otro para el declive (2001-2021), y otro para el período completo (1980-2021).

### Las variables

Mi variable dependiente fue el número de ataques terroristas por celda. Estos son datos de conteo *zero-inflated*, ya que muchas celdas no registran ataques.

Como variables independientes, seleccioné un conjunto basado en la literatura previa sobre geografía del conflicto armado (Buhaug y Rød, 2006; Weidmann, 2015; Hendrix y Salehyan, 2012), y por disposición de datos. En el código estos se identifican como: 

- `Dist to borders`: Distancia al borde territorial (km)
- `Dist to capital`: Distancia a Lima (km)
- `Coca cultiv.`: Presencia de cultivo de coca a gran escala (dummy)
- `Ethnic groups`: Presencia de grupos étnicos excluidos
- `Avg elevation`: Elevación promedio (metros)
- `Open land prop.`: Proporción de terreno abierto
- `No of local langs`: Número de lenguas locales

### Test de Moran's I

El **I de Moran** es el estadístico más utilizado para medir autocorrelación espacial global. Varía de -1 indicando dispersión perfecta, a +1 sugiriendo un agrupamiento perfecto.

El código en R es reproducible y, para resumir, utilicé la función `moran.test()` del paquete `spdep`. El resultado fue que la autocorrelación espacial es **significativamente más pronunciada** durante el período de declive (I = 0.268) que durante el pico de violencia (I = 0.032). Es decir, los ataques se concentraron geográficamente durante el declive.

Esto se explica con que durante el período de repliegue de las fuerzas subversivas (2001-2021), los ataques se concentraron cada vez más en áreas específicas (principalmente VRAEM), creando un patrón de clustering espacial más fuerte.

### Los modelos espaciales: SAR y SEM
Para modelar la dependencia espacial, corrí un Spatial Error Model (SEM) y un Spatial Autoregressive Model (SAR). 

Según Fischer y Wang (2011), hay dos formas principales de modelar la dependencia espacial: a través del término de error (spatial error) o a través de la variable dependiente (spatial lag). Usé SEM para probar si los errores estaban correlacionados espacialmente. *Grosso modo*, la lógica de este algoritmo es que si el modelo  se equivoca al predecir en una celda, probablemente también se equivocará de forma similar en las celdas vecinas. Por otro lado, los SAR incluyen explícitamente el valor de la variable dependiente en las celdas vecinas como un predictor adicional.

Otro punto importante es la definición de "vecino" o *neighbor" usada: Utilicé la definición tipo "Queen": dos celdas son vecinas si comparten un borde o incluso solo una esquina.

También apliqué modelos no espaciales (lineales y de conteo) como  regresiones lineales, *Negative Binominal* y *Zero-inflated Poisson*, pero no profundizaré en ellos. Cabe resaltar que el objetivo de emplear diversos modelos no era identificar el "mejor", sino evaluar la variabilidad en los efectos estimados de las variables explicativas: explicar los fenómenos más que predecir el resultado.

## Conclusiones
Lo primero: que la concentración geográfica de la violencia cambia dramáticamente a lo largo del conflicto: El I de Moran aumentó de 0.032 (pico) a 0.268 (declive), revelando que la violencia se volvió más espacialmente concentrada en el periodo 2001-2021.

Además, durante el declive, los modelos SEM/SAR mostraron mejor ajuste que el OLS, y el parámetro espacial (λ = 0.467, ρ = 0.455) fue altamente significativo.

Por otro lado, también encontré que los efectos de algunas variables son condicionales al período temporal. Variables clave como el cultivo de hoja de coca y la distancia a los bordes invierten su signo entre períodos, demostrando que analizar todo el conflicto como un bloque homogéneo oculta dinámicas críticas.


Para finalizar, todo el análisis es **completamente reproducible**:

- **Repositorio GitHub**: [github.com/castellco/terrorism_peru](https://github.com/castellco/terrorism_peru)
- **Archivo R Markdown**: `carolina_cornejo_tfm.Rmd` (el código completo)
- **Datasets**: Carpeta `/data/data.zip`
- **Shapefiles**: Carpeta `/shapefiles/`
- **Figuras**: Carpeta `/figs/`

## Referencias

Anselin, L. (1988). *Spatial Econometrics: Methods and Models*. Springer.

Buhaug, H., & Rød, J. K. (2006). Local determinants of African civil wars,