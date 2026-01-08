---
title: "Web Scraping con Python: La Euro 2024"
date: 2025-12-31T10:30:00+01:00
draft: true
summary: "Aquí repaso cómo hice un script de web scraping en Python para recolectar las estadísticas de los jugadores de la Euro 2024."
categories:
tags: ["web scraping","fútbol","python"]
featuredImage: "/posts/euro-2024-scraper/featured.gif"
---

![showcase](https://raw.githubusercontent.com/castellco/euro_2024_scraper/main/showcase.gif)

En este post explicaré cómo construí un scraper en Python para recolectar las estadísticas de los jugadores de la Euro 2024 desde la web oficial de la UEFA. 

## ¿Por qué?

Entre junio y julio del 2024 tuvo lugar la EURO 2024. En ese contexto, participé de un reto del chapter local de [Omdena](https://www.omdena.com/) en Tunisia: *[UEFA EURO 2024 - Leveraging Machine Learning and Open Data Sets for Advanced Sports Analytics](https://www.omdena.com/chapter-challenges/leveraging-machine-learning-and-open-datasets-for-advanced-sports-analytics)*. El propósito era analizar este evento en lo deportivo y lo económico. Si bien nos quedamos cortos en este último aspecto, fue un espacio interesante para aplicar técnicas de ciencia de datos al mundo del fútbol.

Así, varios colegas se dispusieron a buscar datasets ya existentes: estadísticas de cada partido, datasets históricos o lo que haya. Cuando visité [la página de la EURO](https://www.uefa.com/european-qualifiers/statistics/players/), vi que era posible scrapearla para generar un dataset.

A modo de documentación de ese ejercicio, en este post resumo la lógica detrás del scraper en Python + Selenium que hice y que extrae las estadísticas de jugadores desde la web de la UEFA y las prepara en un `pandas.DataFrame` para análisis exploratorio y modelado.


## Resumen técnico

El objetivo principal es automatizar la recolección de datos de los jugadores de la [EURO](https://www.uefa.com/european-qualifiers/statistics/players/) a falta de acceso a una API oficial. El output debía ser un dataset en formato tabular.

Usé Python por ser el lenguaje de preferencia en los proyectos de Omdena en los que he participado, aunque también R hubiera servido. La librería principal fue `Selenium`, que permite controlar el navegador web (en mi caso, Chrome) para interactuar con páginas dinámicas que cargan contenido vía JavaScript. 

Hacia los meses que hice este scraper, los términos y condiciones de la web de la UEFA permitían el web scraping para fines no comerciales. Recomiendo revisar los términos actuales antes de ejecutar cualquier scraper.

## Pasos

El scraper, que es open source, está disponible en GitHub:

{{< github repo="castellco/euro_2024_scraper" >}}

Las condiciones previas son tener conexión a internet, Python 3.8+ instalado y las librerías necesarias (ver `requirements.txt` en el repo).

Básicamente, los pasos para ejecutarlo son:

### Preparar del entorno
Primero se importan las librerías necesarias e instala el driver de Chrome automáticamente con `webdriver_manager`. Luego, se configuran las opciones del navegador Chrome (p. ej. `--start-maximized`). Esto es para que se ejecute Chrome en modo gráfico y no headless —ya que algunas tablas no cargan bien en modo headless— y también por una preferencia personal: prefiero ver lo que hace el scraper en tiempo real.

```python
# 1: import libraries -----------------------------------------------------
import time
from selenium import webdriver
from selenium.webdriver.chrome.service import Service 
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By
from selenium.webdriver import ActionChains
import pandas as pd
import re
chrome_options = webdriver.ChromeOptions()
chrome_options.add_argument("--start-maximized")
```

### Abrir la web y preparar la página
Posteriormente, se instala e inicia el `webdriver.Chrome(...)` y se carga la página `https://www.uefa.com/european-qualifiers/statistics/players/`.

```python
# 2: enter website, reject cookies and define function to scroll ----------
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
driver.get("https://www.uefa.com/european-qualifiers/statistics/players/")
```

Esperamos 2 segundos. Como se podrá apreciar, a lo largo del script usé varias pausas con `time.sleep()` para dar tiempo a que la página cargue dinámicamente y para, en teoría, evitar bloqueos por parte del servidor web. Luego, para indicarle a Selenium qué lugar de la página clickear para rechazar las cookies, uso un CSS selector que apunta al botón de cookies ya que no me fue posible identificar el XPath. 

En este punto, es importante comentar que para identificar CSS selectors, la extensión de Chrome [SelectorGadget](
https://chromewebstore.google.com/detail/selectorgadget/mhjhnkcfbdhnjickkkdbjoemdmbfginb?hl=en-US) siempre me ha parecido excelente.

Rechazadas ya las cookies, definí la función `scroll_to_sponsors()` para desplazar la página hacia abajo y con ello forzar la carga completa de la tabla dinámica de jugadores. En específico, esta función busca el banner de sponsors (que en ese entonces estaba al final de la página) usando su XPath y desplaza la vista hasta ese elemento. Esto es necesario porque la tabla de jugadores carga más filas a medida que se hace scroll hacia abajo. Necesitaba tener toda la tabla cargada.

```python
# define function to scroll down, in order to make rest of the table discoverable
def scroll_to_sponsors():
    try:
        sponsors_xpath = "//div[contains(text(), 'Official global sponsors')]"
        select_sponsors_banner = driver.find_element(By.XPATH, sponsors_xpath)
        ActionChains(driver)\
            .scroll_to_element(select_sponsors_banner)\
            .perform()
        time.sleep(2)
    except:
        try:
            sponsors_xpath = '//div[@class="pk-container pk-bg--background lazyloaded" and @role="region" and @pk-theme="light" and @aria-label=""]'
            select_sponsors_banner = driver.find_element(By.XPATH, sponsors_xpath)
            ActionChains(driver)\
                .scroll_to_element(select_sponsors_banner)\
                .perform()
            time.sleep(2)
        except: 
            print("The scroll_to_sponsors function didn't work.")
            time.sleep(2)
```

También creé un dataset vacío con `pandas.DataFrame()` y varias listas vacías para almacenar los datos de cada jugador mientras se itera sobre ellos.

```python
# will need these later:
dataset = pd.DataFrame()
name, national_team, club, overview_figures, overview_labels, stats_figures, stats_labels = [], [], [], [], [], [], []
```

### Definir funciones auxiliares de extracción
Luego, definí varias funciones auxiliares para extraer datos específicos de la página. Esta parte fue la que, de lejos, me demandó más tiempo y esfuerzo. Fue prueba y error. Recozco que hay muchas cosas mejorables, pero el objetivo era tener un scraper funcional en un tiempo razonable.

La primera función, `extract_name_and_teams()`, extrae el nombre completo del jugador, su selección nacional y su club actual. Usé varios `try/except` para manejar casos donde algún dato no esté disponible o el selector falle.Nuevamente usé CSS selectors y XPath para localizar los elementos gracias a la extensión *SelectorGadget*.

La función `extract_list_with_xpath(labels_xpath)` toma un XPath como argumento y devuelve una lista de textos de los elementos que coinciden con ese XPath. Esto se usa para extraer tanto las etiquetas como las cifras de las secciones de "overview" y "statistics".

`open_accordions` es una función que abre las secciones colapsables (acordeones) en la pestaña de estadísticas del jugador para asegurarse de que todos los datos estén visibles y accesibles para la extracción.

Finalmente, `update_dataset(dataset)` toma el dataset actual y agrega una nueva fila con los datos del jugador actual. Esta función maneja la normalización de columnas entre distintos jugadores, evitando duplicados y asegurando que todas las filas tengan las mismas columnas, incluso si algunos jugadores no tienen ciertos datos. Esta función es mejorable por los tantos `if/elif` anidados, pero en el momento sirvió para el propósito. Un punto de mejora es simplificar los casos en los que ciertos jugadores tienen más o menos columnas que otros.

```python
# 3: define main functions ------------------------------------------------
def extract_name_and_teams():
    try:
        name = driver.find_element(By.CSS_SELECTOR, '.player-header__name--first').text + ' ' + driver.find_element(By.CSS_SELECTOR, '.player-header__name--last').text
        print(name)
    except:
        print('Player name and/or last name not found.')

    try:
        # national_team = driver.find_element(By.CSS_SELECTOR, '.player-header__teams > div:nth-child(1) > a:nth-child(3) > pk-identifier:nth-child(1) > div:nth-child(2) > span:nth-child(1)').text
        # print(national_team)
        national_team = driver.find_element(By.XPATH, '//span[@class="player-header__team-name pk-text--text-01"][1]').text
        print(national_team)
    except:
        print('National team not found.')

    try:
        club = driver.find_element(By.CSS_SELECTOR, '.player-header__teams > div:nth-child(2) > a:nth-child(3) > pk-identifier:nth-child(1) > div:nth-child(2) > span:nth-child(1)').text
        print(club)
    except:
        try:
            print('Club not found. Trying another xpath...')
            club = driver.find_element(By.XPATH, '/html/body/div[3]/div/div/div[2]/div[3]/div[2]/div[2]/pk-identifier/div/div[1]/div[2]/pk-identifier/div/span').text
            print(club)
        except:
            print('Club not found.')
            club = "" 

    return name, national_team, club

def extract_list_with_xpath(labels_xpath):
    if driver.find_elements(By.XPATH, "//h2[contains(text(), 'Qualifying stats')]"):
        labels_text = []
        print('Player only participated in qualifyings.')
    else:
        all_labels = driver.find_elements(By.XPATH, labels_xpath)
        labels_text = [label.text for label in all_labels]
    return labels_text

def open_accordions():
    for i in range(0, 6):
        try: 
            driver.find_element(By.CSS_SELECTOR, '#accordion-item-' + str(i) + ' > pk-accordion-item-title:nth-child(1) > h2:nth-child(1)').click()
            time.sleep(2)
        except: 
            print('There are no more accordions to open.')
            
def update_dataset(dataset):
    player_info = [name, national_team, club] + overview_figures
    if stats_figures:
        player_info += stats_figures
    else:
        player_info += [""] * len(stats_figures)

    if stats_labels:
        columns = ["name", "national_team", "club"] + overview_labels + stats_labels
    else:
        columns = ["name", "national_team", "club"] + overview_labels

    new_row = pd.DataFrame([player_info], columns=columns)
    new_row = new_row.loc[:,~new_row.columns.duplicated()].copy()

    dataset = dataset.loc[:,~dataset.columns.duplicated()].copy() 

    if dataset.empty:
        print("Condition met: dataset.empty")
    elif len(dataset.columns) == len(columns):
        print("Condition met: len(dataset.columns) == len(columns)")
        try:
            dataset = dataset[columns]
        except:
            print('Something went wrong when executing the if statement of the len(dataset.columns) == len(columns) condition in case of ' + name + ' from ' + national_team)
    elif len(dataset.columns) < len(columns):
        print("Condition met: len(dataset.columns) < len(columns)")
        try: 
            for column in columns:
                if column not in dataset.columns:
                    dataset[column] = ""
                else:
                    continue
            dataset = dataset[new_row.columns]
        except:
            print('Something went wrong when executing the if statement of the len(dataset.columns) < len(columns) condition in case of ' + name + ' from ' + national_team)
    elif len(dataset.columns) > len(columns):
        print("Condition met: len(dataset.columns) > len(columns)")
        try: 
            for column in dataset.columns:
                if column not in columns:
                    new_row[column] = ""
                else:
                    continue
            new_row = new_row[dataset.columns]
        except:
            print('Something went wrong when executing the if statement of the len(dataset.columns) > len(columns) condition in case of ' + name + ' from ' + national_team)
    else:
        print('Something went wrong when executing update_dataset function.')
    
    dataset = pd.concat([dataset, new_row], ignore_index=True)

    return dataset
```
### Ejecución del scraper

Ahora, se ejecuta el scraper. Este es el paso que demora más, ya que hay muchos países y jugadores, y por los tiempos de espera que añadí por las razones que comenté párrafos arriba.

La lógica es iterar sobre cada país participante (del 2 al 54 en el acordeón de selección de países) y luego sobre cada jugador listado para ese país. Para próximaas ediciones, el range podría cambiar. 

Por cada jugador, se extraen los datos usando las funciones definidas previamente y se actualiza el dataset.

```python
# 4: scraping work: iterate over each country and each player -------------
for i in range(2, 55): 
    # open main site
    driver.get("https://www.uefa.com/european-qualifiers/statistics/players/")
    # select main tournament (excluding qualiying)
    time.sleep(2)
    try:
        main_tournament = driver.find_element(By.XPATH, '//pk-accordion-item[1]/pk-accordion-item-content/pk-radio/pk-radio-option[1]')
        time.sleep(2)
        main_tournament.click()
        time.sleep(2)
    except:
        main_tournament = driver.find_element(By.XPATH, '//input[@class="pk-radio" and @name="phase" and @title="phase" and @type="radio" and @id="tournament" and @value="TOURNAMENT" and @part="input"]')
        time.sleep(2)
        main_tournament.click()
        time.sleep(2)
    # select country
    xpath_country = '//pk-accordion-item[2]/pk-accordion-item-content/div/pk-radio/pk-radio-option[' + str(i) + ']/span'
    select_country = driver.find_element(By.XPATH, xpath_country)
    country_name = select_country.text
    print('---------- Accessing info of ' + country_name + ' ----------')
    time.sleep(2)
    select_country.click() # select country
    time.sleep(3)
    # scroll down twice, as needed to discover the whole page
    scroll_to_sponsors()
    scroll_to_sponsors()
    # gather all players' stats website links
    try: 
        player_xpath = '//a[contains(@class, "pk-w--100") and contains(@href, "/api/v1/linkrules/player/") and contains(@href, "/statistics?competitionId=3&phase=TOURNAMENT")]'
        select_player = driver.find_elements(By.XPATH, player_xpath)
    except:
        print('Seems like the site of ' + country_name + ' is empty.')
        continue
    players_ids = []
    for link in select_player:
        href = link.get_attribute('href')
        player_id = re.search(r'player/(\d+)/', href).group(1)
        players_ids.append(player_id)
    for player_id in players_ids:
        time.sleep(2)
        driver.get('https://www.uefa.com/euro2024/teams/players/' + player_id + '/')
        print('---------- Working on player whose ID is ' + player_id + ' -------------')
        time.sleep(2)
        name, national_team, club = extract_name_and_teams()
        overview_labels = extract_list_with_xpath('//span[@class="player-profile-category"]')
        overview_figures = extract_list_with_xpath('//span[@class="player-profile-value"]')
        print(overview_labels)
        print(overview_figures)
        time.sleep(2)
        driver.get('https://www.uefa.com/euro2024/teams/players/' + player_id + '/statistics/')
        time.sleep(2)
        scroll_to_sponsors()
        open_accordions()
        stats_labels = extract_list_with_xpath('//div[@slot="stat-label"]')
        stats_figures = extract_list_with_xpath('//div[@slot="stat-value"]')
        print(stats_labels)
        print(stats_figures)
        dataset = update_dataset(dataset)
        print('---------- End of process for player whose ID is ' + player_id + ' ----------')
        time.sleep(2)
```
Al final esta sección, se obtiene un dataset (en mi caso, una tabla de 621x66).

El dataset publicado está en el repo en [Dagshub](https://dagshub.com/Omdena/TunisiaLocalChapter_UEFAEURO2024/src/906eefeacb49f4e8318dc8e6f890c26b726880bb/Datasets/players_stats_uefa_scraper.csv).
