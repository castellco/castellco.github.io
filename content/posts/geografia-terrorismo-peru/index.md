---
title: "La geografía del terrorismo"
date: 2025-02-07T10:00:00+01:00
draft: true
summary: "Análisis espacial de incidentes y patrones de violencia en Perú usando datos públicos."
tags: ["datos espaciales","Perú","GIS", "R"]
featureimage: "https://raw.githubusercontent.com/castellco/terrorism_peru/refs/heads/main/figs/map_full.png"
---
{{< github repo="castellco/terrorism_peru" >}}

En el contexto de mi Trabajo de Fin de Máster (TFM) del Máster Universitario en Ciencias Sociales Computacionales en la Universidad Carlos III de Madrid, me propuse abordar el Conflicto Armado Interno  desde una perspectiva espacial. Me interesaba 1) Conocer si y/o en qué grado hubo un efecto de difusión espacial de los ataques terroristas; y 2) practicar el tratamiento de datos espaciales y herramientas GIS en R.

El análisis espacial de conflictos armados presenta desafíos metodológicos únicos: las observaciones no son independientes entre sí, el espacio importa, y los eventos tienden a agruparse. Así, en mi TFM apliqué modelos espaciales para estudiar la difusión de ataques terroristas en Perú durante el conflicto armado interno (1980-2021), comparando diferentes períodos temporales y técnicas de modelado.

## Desafío metodológico: ¿Por qué modelos espaciales?

### El problema de la dependencia espacial

Los métodos tradicionales de regresión (OLS) asumen que las observaciones son **independientes entre sí**. Sin embargo, en fenómenos espaciales como conflictos armados, esta suposición se viola sistemáticamente.

> “Todo está relacionado con todo lo demás, pero las cosas cercanas están más relacionadas que las distantes.”  
> — <cite> Waldo Tobler (1970)</cite>

Esta, la llamada "Primera ley de Tobler", es la madre de varios conceptos clave en análisis espacial. En específico, en mi TFM refiero mucho a la **autocorrelación espacial**, que describe cómo las observaciones en ubicaciones geográficas cercanas tienden a ser más similares entre sí que las distantes.

Ignorar esta dependencia lleva a estimaciones sesgadas de los efectos, errores estándar incorrectos (generalmente subestimados), e inferencias estadísticas inválidas. Por eso se debían usar modelos espaciales.

## Metodología

Siguiendo las recomendaciones de Buhaug y Rød (2006), utilicé **celdas de grilla (grid cells)** de 0.5 × 0.5 grados decimales como unidades de análisis en lugar de divisiones administrativas tradicionales, como distritos o provincias.

Este enfoque tiene ventajas, como que las celdas no cambian en tamaño, forma o número a lo largo del tiempo, permiten controlar mejor por decisiones políticas que podrían afectar la frecuencia de eventos, constituyen entidades inherentemente apolíticas (Tollefsen et al., 2012), entre otros.

![Grid cells sobre territorio peruano](https://raw.githubusercontent.com/castellco/terrorism_peru/refs/heads/main/figs/map_grids.png)


### Los datos

Integré datos de múltiples fuentes georreferenciadas:

1. **Global Terrorism Database (GTD)**: Mi principal dataset, que contiene información de ~200,000 incidentes terroristas a nivel global (1970-2021)
2. **PRIO-GRID**: Una base de Variables geodemográficas a nivel de celda 0.5×0.5
3. **xSUB**: Datos subnacionales de conflicto compatibles con PRIO-GRID
4. **Shapefiles**: Geometrías de celdas mundiales y fronteras de Perú

### El procesamiento
Básicamente, y para resumir, hice un *point-in-polygon spatial join* para asignar los ataques (los puntos) a los grid cells (los polygons). Luego, agregué los eventos (los ataques terroristas) por celda y construí tres sub datasets temporales: uno para el pico de la violencia (1980-2000), otro para el declive (2001-2021), y otro para el período completo (1980-2021).

### Variables del modelo

**Variable dependiente**:

- Número de ataques terroristas por celda de grilla (datos de conteo, que a la vez son zero-inflated, ya que muchas celdas no registran ataques).

**Variables independientes**:
- `Dist to borders`: Distancia al borde territorial (km)
- `Dist to capital`: Distancia a Lima (km)
- `Coca cultiv.`: Presencia de cultivo de coca a gran escala (dummy)
- `Ethnic groups`: Presencia de grupos étnicos excluidos
- `Avg elevation`: Elevación promedio (metros)
- `Open land prop.`: Proporción de terreno abierto
- `No of local langs`: Número de lenguas locales

## Análisis de autocorrelación espacial: Moran's I

Antes de modelar, es crucial **detectar y cuantificar** la autocorrelación espacial.

### Test de Moran's I

El **I de Moran** es el estadístico más utilizado para medir autocorrelación espacial global. Varía de -1 (dispersión perfecta) a +1 (agrupamiento perfecto).

**Hipótesis**:
- H0: No existe autocorrelación espacial (el fenómeno que se está analizando exhibe completa aleatoriedad espacial)
- H1: Existe autocorrelación espacial significativa (el fenómeno parece presentar un patrón espacial no aleatorio)

Así, la autocorrelación espacial es **significativamente más pronunciada** durante el período de declive (I = 0.268) que durante el pico de violencia (I = 0.032).

**Interpretación**:
Durante el período de repliegue de las fuerzas subversivas (2001-2021), los ataques se concentraron cada vez más en áreas específicas (principalmente VRAEM - Valle de los ríos Apurímac, Ene y Mantaro), creando un **patrón de clustering espacial más fuerte**.

## Modelos espaciales aplicados

### 1. Spatial Error Model (SEM)

El modelo SEM captura la **dependencia espacial en los términos de error**.

**Especificación**:
```
y = Xβ + ε
ε = λWε + u
```

Donde:
- `λ` (lambda): parámetro de autocorrelación espacial de los errores
- `W`: matriz de pesos espaciales
- `u`: error no correlacionado espacialmente

**Cuándo usarlo**: Cuando la autocorrelación espacial proviene de variables omitidas espacialmente correlacionadas.

**Implementación en R**:
```r
library(spatialreg)

# Definir vecindad tipo "Queen" (bordes y vértices compartidos)
nb <- poly2nb(grid_sf, queen = TRUE)

# Crear matriz de pesos row-standardized
lw <- nb2listw(nb, style = "W")

# Ajustar modelo SEM
sem_model <- errorsarlm(
  attacks ~ dist_borders + dist_capital + coca + ethnic + 
            elevation + open_land + languages,
  data = df,
  listw = lw
)
```

**Resultados SEM**:

| Variable | Pico | Declive | Completo |
|----------|------|---------|----------|
| **λ (lambda)** | 0.032 | **0.467***  | 0.031 |
| Dist to borders | -0.015 | **0.002*** | -0.015 |
| Dist to capital | -0.018 | 0.000 | -0.018 |
| Coca cultiv. | -5.334 | 1.185 | -7.735 |
| Avg elevation | **0.009†** | 0.000 | **0.009†** |
| No of local langs | -8.878 | **-0.076†** | **-9.072†** |

**Interpretación**:
- El parámetro λ es **significativo solo en el período de declive** (0.467***, p < 0.001)
- Evidencia de **autocorrelación espacial residual pronunciada** en 2001-2021
- Durante el declive, la distancia a fronteras tiene un efecto **positivo** y significativo (inversión de tendencia)

### 2. Spatial Autoregressive Model (SAR)

El modelo SAR incorpora la **dependencia espacial en la variable dependiente**.

**Especificación**:
```
y = ρWy + Xβ + ε
```

Donde:
- `ρ` (rho): parámetro de autocorrelación espacial de la variable dependiente
- `Wy`: variable dependiente espacialmente rezagada (spatial lag)

**Cuándo usarlo**: Cuando existe un proceso de **difusión o contagio** directo entre unidades vecinas.

**Implementación en R**:
```r
# Ajustar modelo SAR
sar_model <- lagsarlm(
  attacks ~ dist_borders + dist_capital + coca + ethnic + 
            elevation + open_land + languages,
  data = df,
  listw = lw
)
```

**Resultados SAR**:

| Variable | Pico | Declive | Completo |
|----------|------|---------|----------|
| **ρ (rho)** | 0.032 | **0.455***  | 0.032 |
| Dist to borders | -0.016 | 0.001 | -0.015 |
| Dist to capital | -0.018 | 0.000 | -0.018 |
| Coca cultiv. | -5.300 | 1.162 | -7.678 |
| Avg elevation | **0.008†** | 0.000 | **0.008†** |
| No of local langs | -8.717 | -0.058 | -8.907 |

**Interpretación**:
- El parámetro ρ también es **significativo solo en el período de declive** (0.455***)
- Confirma proceso de **difusión espacial** durante 2001-2021
- Resultados consistentes con SEM, validando la estructura espacial

### 3. Linear Model (OLS)

Modelo de regresión lineal tradicional **sin componente espacial**, usado como baseline para comparación.

**Resultados clave**:

| Variable | Pico | Declive | Completo |
|----------|------|---------|----------|
| Dist to borders | -0.017 | **0.001*** | -0.017 |
| Coca cultiv. | -5.484 | **1.695*** | -7.939 |
| Ethnic groups | 5.563 | **0.211*** | 6.522 |
| No of local langs | -8.911 | **-0.074†** | **-9.103†** |
| **R² Adj** | 0.010 | 0.067 | 0.010 |

**Problema**: R² muy bajo indica **pobre ajuste del modelo**. La omisión de la estructura espacial perjudica el rendimiento predictivo.

### 4. Negative Binomial Model

Modelo de conteo que maneja **sobredispersión** en la variable dependiente.

**Por qué Negative Binomial**:
- Variable dependiente = conteos (0, 1, 2, ... ataques)
- **Zero-inflated**: 301 de 488 celdas (62%) tienen 0 ataques
- Media (11.39) ≠ Varianza (12,210) → **sobredispersión extrema**
- Negative Binomial maneja mejor que Poisson cuando varianza >> media

**Implementación en R**:
```r
library(MASS)

nb_model <- glm.nb(
  attacks ~ dist_borders + dist_capital + coca + ethnic + 
            elevation + open_land + languages,
  data = df
)
```

**Resultados Negative Binomial**:

| Variable | Pico | Declive | Completo |
|----------|------|---------|----------|
| Dist to borders | 0.002 | **0.008*** | 0.002 |
| Dist to capital | **-0.005***  | **-0.003*** | **-0.005*** |
| Avg elevation | **0.001*** | 0.000 | **0.001*** |
| No of local langs | **-0.703***  | **-0.533*** | **-0.704*** |
| **AIC** | 1859.3 | **352.1** | 1907.0 |

**Hallazgo clave**: El modelo NB muestra el **mejor ajuste general** (AIC más bajo) y revela efectos significativos de distancia a capital y número de lenguas locales **consistentes en los tres períodos**.

## Comparación de modelos

### Criterios de información

| Modelo | Pico AIC | Declive AIC | Completo AIC |
|--------|----------|-------------|--------------|
| SEM | 6000.7 | **1145.3** | 6005.0 |
| SAR | 6000.7 | **1144.2** | 6005.0 |
| Linear | 5998.9 | 1193.5 | 6003.2 |
| Negative Binomial | **1859.3** | **352.1** | **1907.0** |

**Observaciones**:
1. Los modelos espaciales (SEM/SAR) muestran **mejor ajuste en el período de declive**
2. El modelo Negative Binomial tiene **AIC consistentemente más bajo** en todos los períodos
3. El período de declive tiene mejor ajuste en **todos los modelos** (AIC menores)

### Efectos de variables clave por modelo

#### Coca cultivation

| Modelo | Pico | Declive | Completo |
|--------|------|---------|----------|
| SEM | -5.334 | +1.185 | -7.735 |
| SAR | -5.300 | +1.162 | -7.678 |
| Linear | -5.484 | **+1.695*** | -7.939 |
| NB | -0.290 | +4.796 | -0.361 |

**Patrón**: Efecto **negativo** durante pico, **positivo** durante declive (aunque solo significativo en Linear model).

**Interpretación**: Durante el declive, los grupos terroristas se replegaron hacia zonas de cultivo de coca (especialmente VRAEM), creando una asociación positiva entre coca y ataques.

#### Average elevation

| Modelo | Pico | Declive | Completo |
|--------|------|---------|----------|
| SEM | **0.009†** | 0.000 | **0.009†** |
| SAR | **0.008†** | 0.000 | **0.008†** |
| Linear | **0.008†** | 0.000 | **0.008†** |
| NB | **0.001*** | 0.000 | **0.001*** |

**Patrón**: Efecto **positivo y significativo** en pico y período completo, **no significativo** en declive.

**Interpretación**: Durante el pico de violencia, las zonas de mayor elevación (más inaccesibles para fuerzas del orden) fueron más propensas a ataques. Este efecto desaparece en el declive.

#### Number of local languages

| Modelo | Pico | Declive | Completo |
|--------|------|---------|----------|
| SEM | -8.878 | **-0.076†** | **-9.072†** |
| SAR | -8.717 | -0.058 | -8.907 |
| Linear | -8.911 | **-0.074†** | **-9.103†** |
| NB | **-0.703*** | **-0.533*** | **-0.704*** |

**Patrón**: Efecto **negativo consistente** en todos los modelos y períodos.

**Interpretación contraintuitiva**: Áreas con mayor número de lenguas locales tuvieron **menos** ataques. Posible explicación: mayor diversidad lingüística correlaciona con organización comunitaria más fuerte (rondas campesinas de autodefensa).

## Hallazgos metodológicos clave

### 1. La autocorrelación espacial varía temporalmente

El **I de Moran aumentó 8.4 veces** del período de pico (0.032) al de declive (0.268), indicando que:

- El terrorismo se **concentró geográficamente** durante el declive
- Los modelos espaciales son **especialmente importantes** para analizar períodos post-conflicto
- La estructura espacial del conflicto **cambia con el tiempo**

### 2. Los efectos de variables se invierten entre períodos

Múltiples variables muestran **inversión de signo** entre pico y declive:

- **Coca cultivation**: Negativo → Positivo
- **Distance to borders**: Negativo → Positivo  
- **Open land proportion**: Negativo → Positivo

**Implicación metodológica**: Analizar todo el período como un bloque homogéneo **oculta dinámicas temporales críticas**.

### 3. Los modelos espaciales superan a OLS en períodos de alta autocorrelación

Durante el declive:
- SEM/SAR AIC: ~1145
- Linear AIC: 1193.5

Pero durante el pico:
- Diferencias de AIC son **mínimas**

**Conclusión**: La ventaja de modelos espaciales es **condicional a la intensidad de autocorrelación espacial**.

### 4. Zero-inflation requiere atención especial

Con 62% de celdas sin ataques:
- Modelos Negative Binomial superan dramáticamente a Linear (AIC: 352 vs 1194 en declive)
- **Zero-Inflated Poisson** fue probado inicialmente pero descartado (resultados en Apéndice del TFM)
- La elección del modelo de conteo es **crítica** para datos de conflicto

## Implementación técnica

### Construcción de matriz de pesos espaciales

```r
library(spdep)

# 1. Definir vecindad tipo Queen
nb_queen <- poly2nb(grid_cells, queen = TRUE)

# Verificar celdas sin vecinos
summary(nb_queen)
# Resultado: 1 celda sin vecinos → eliminada del análisis

# 2. Crear matriz de pesos row-standardized
W <- nb2listw(nb_queen, style = "W", zero.policy = FALSE)

# 3. Visualizar estructura de vecindad
plot(st_geometry(grid_cells), border = "grey")
plot(nb_queen, coords = st_coordinates(st_centroid(grid_cells)), 
     add = TRUE, col = "red")
```

**Alternativas consideradas**:
- **Rook contiguity**: Solo bordes compartidos (más restrictiva)
- **K-nearest neighbors**: K vecinos más cercanos (asegura conectividad)
- **Distance-based**: Vecinos dentro de X km (permite pesos continuos)

Opté por **Queen** porque:
- Captura mejor la contigüidad geográfica real
- Es el estándar en análisis de conflictos
- Permite comparación con literatura existente

### Manejo de datos zero-inflated

```r
# Distribución de la variable dependiente
table(df$attacks == 0)
# FALSE  TRUE 
#   187   301  → 62% zeros

# Estrategia 1: Negative Binomial
library(MASS)
nb_model <- glm.nb(attacks ~ ., data = df)

# Estrategia 2: Zero-Inflated Poisson (probado pero descartado)
library(pscl)
zip_model <- zeroinfl(attacks ~ . | ., data = df, dist = "poisson")

# Estrategia 3: Hurdle model (no implementado)
# hurdle_model <- hurdle(attacks ~ ., data = df, dist = "poisson")
```

**Decisión final**: Negative Binomial porque:
1. Maneja sobredispersión (varianza >> media)
2. Más simple que ZIP
3. En ZIP, las estimaciones de ambas partes (Poisson y logística) eran casi idénticas → parsimonia favorece NB

### Validación de modelos

```r
# Test de Moran en residuos (detectar autocorrelación residual)
lm_residuals <- residuals(linear_model)
moran.test(lm_residuals, listw = W)
# Resultado: Moran's I significativo → justifica modelos espaciales

# Test de Breusch-Pagan (heterocedasticidad)
bptest(linear_model)

# Test de Lagrange Multiplier para dependencia espacial
lm.LMtests(linear_model, W, test = "all")
# LMerr: Test para SEM
# LMlag: Test para SAR
```

## Desafíos técnicos y soluciones

### 1. Integración de múltiples fuentes de datos

**Desafío**: Combinar datos de GTD (puntos), PRIO-GRID (grillas), xSub (tablas), shapefiles.

**Solución**:
```r
# Spatial join point-in-polygon
attacks_per_cell <- st_join(
  attacks_points,      # GTD data como sf points
  grid_cells,          # PRIO-GRID como sf polygons
  join = st_within
) %>%
  group_by(cell_id) %>%
  summarise(n_attacks = n())

# Merge con variables geodemográficas
final_data <- grid_cells %>%
  left_join(attacks_per_cell, by = "cell_id") %>%
  left_join(priogrid_vars, by = "cell_id") %>%
  left_join(xsub_vars, by = "cell_id") %>%
  mutate(n_attacks = replace_na(n_attacks, 0))
```

### 2. Proyecciones cartográficas

**Desafío**: Asegurar que todos los layers usen la misma proyección.

**Solución**:
```r
# Verificar CRS
st_crs(grid_cells)
st_crs(attacks_points)

# Reprojectar si es necesario
attacks_points <- st_transform(attacks_points, crs = st_crs(grid_cells))

# Para Perú, usar proyección apropiada
peru_crs <- "+proj=utm +zone=18 +south +datum=WGS84"
grid_cells <- st_transform(grid_cells, crs = peru_crs)
```

### 3. Celda sin vecinos

**Desafío**: Una celda aislada causaba errores en cálculos de matriz de pesos.

**Solución**:
```r
# Identificar celdas sin vecinos
no_neighbors <- which(sapply(nb_queen, length) == 0)

# Eliminar del análisis
grid_cells_clean <- grid_cells[-no_neighbors, ]
# Resultado: 488 celdas (de 489 originales)
```

### 4. Interpretación de efectos en modelos espaciales

**Desafío**: En SAR, los efectos no son directamente interpretables como en OLS porque incluyen **efectos indirectos** (spillovers).

**Solución**: Calcular impactos directos e indirectos.

```r
# Calcular impactos en modelo SAR
impacts_sar <- impacts(sar_model, listw = W, R = 1000)
summary(impacts_sar, zstats = TRUE)

# Resultado:
# - Direct impact: efecto en la misma celda
# - Indirect impact: efecto en celdas vecinas (spillover)
# - Total impact: suma de ambos
```

## Limitaciones y trabajo futuro

### Limitaciones del estudio

1. **Calidad de datos**: GTD es una base global, no especializada en Perú. Puede subreportar eventos no letales (violaciones, robos, quema de viviendas).

2. **Definición de vecindad**: Usé solo Queen contiguity. Otros criterios (distancia, K-nearest neighbors) podrían revelar patrones diferentes.

3. **Variables omitidas**: No incluí variables de presencia estatal, infraestructura vial, o historial de violencia previa por limitaciones de datos.

4. **Causalidad**: Los modelos muestran **asociaciones**, no relaciones causales. La endogeneidad espacial complica la inferencia causal.

### Extensiones futuras

**1. Modelos espacio-temporales**

Incorporar dimensión temporal explícitamente:
```r
# Spatio-temporal model
library(splm)
st_model <- spml(
  attacks ~ vars,
  data = panel_data,
  listw = W,
  model = "within",
  spatial.error = "b",
  lag = TRUE
)
```

**2. Geographically Weighted Regression (GWR)**

Permitir que los coeficientes **varíen espacialmente**:
```r
library(GWmodel)
gwr_model <- gwr.basic(
  attacks ~ vars,
  data = sp_data,
  bw = bw.gwr(attacks ~ vars, data = sp_data, kernel = "gaussian"),
  kernel = "gaussian"
)
```

**3. Análisis de hotspots**

Identificar clusters estadísticamente significativos:
```r
# Local Moran's I
local_moran <- localmoran(df$attacks, W)

# Getis-Ord Gi*
gi_star <- localG(df$attacks, W)
```

**4. Machine learning espacial**

Integrar random forests con estructura espacial:
```r
library(ranger)
# Incluir spatial lags como features
df$lag_attacks <- lag.listw(W, df$attacks)

rf_spatial <- ranger(
  attacks ~ . + lag_attacks,
  data = df,
  importance = "permutation"
)
```

## Recursos y reproducibilidad

### Código y datos

Todo el análisis es **completamente reproducible**:

- **Repositorio GitHub**: [github.com/castellco/terrorism_peru](https://github.com/castellco/terrorism_peru)
- **Archivo R Markdown**: `carolina_cornejo_tfm.Rmd` (incluye código completo)
- **Datasets**: Carpeta `/data/data.zip`
- **Shapefiles**: Carpeta `/shapefiles/`
- **Figuras**: Carpeta `/figs/`

### Paquetes de R utilizados

```r
# Manipulación de datos
library(tidyverse)
library(dplyr)

# Análisis espacial
library(sf)           # Geometrías espaciales
library(spdep)        # Dependencia espacial
library(spatialreg)   # Modelos espaciales (SEM, SAR)

# Modelos de conteo
library(MASS)         # Negative Binomial
library(pscl)         # Zero-inflated models

# Visualización
library(ggplot2)
library(tmap)         # Mapas temáticos
library(viridis)      # Paletas de colores

# Utilidades
library(broom)        # Tidying model outputs
```

### Instalación del entorno

```r
# Instalar paquetes necesarios
packages <- c("tidyverse", "sf", "spdep", "spatialreg", 
              "MASS", "pscl", "ggplot2", "tmap")

install.packages(packages)

# Clonar repositorio
# git clone https://github.com/castellco/terrorism_peru.git

# Ejecutar análisis
rmarkdown::render("carolina_cornejo_tfm.Rmd")
```

## Conclusiones

Este proyecto demuestra la **importancia crítica de incorporar la estructura espacial** en el análisis de conflictos armados. Los principales hallazgos metodológicos son:

### 1. La autocorrelación espacial no es constante
El I de Moran aumentó de 0.032 (pico) a 0.268 (declive), revelando que la **concentración geográfica de la violencia cambia dramáticamente** a lo largo del conflicto.

### 2. Los modelos espaciales son esenciales cuando hay autocorrelación fuerte
Durante el declive, los modelos SEM/SAR mostraron mejor ajuste (AIC ~1145) que OLS (AIC 1194), y el parámetro espacial (λ = 0.467, ρ = 0.455) fue altamente significativo.

### 3. Los efectos de variables son condicionales al período temporal
Variables clave como coca cultivation y distance to borders **invierten su signo** entre períodos, demostrando que analizar todo el conflicto como un bloque homogéneo **oculta dinámicas críticas**.

### 4. La elección del modelo de conteo importa con zero-inflation
Con 62% de ceros, el modelo Negative Binomial superó dramáticamente a OLS y mostró efectos robustos de variables como distancia a capital y número de lenguas locales.

### Implicaciones para análisis de conflictos

Este trabajo muestra que el análisis riguroso de conflictos armados requiere:

✓ **Datos desagregados** (grid-cell level, no país/región)  
✓ **Modelos espaciales** cuando existe autocorrelación  
✓ **Análisis temporal diferenciado** (pico vs declive vs completo)  
✓ **Modelos de conteo apropiados** para datos zero-inflated  
✓ **Reproducibilidad completa** (código + datos públicos)

## Referencias

### Metodológicas

Anselin, L. (1988). *Spatial Econometrics: Methods and Models*. Springer.

Buhaug, H., & Rød, J. K. (2006). Local determinants of African civil wars,