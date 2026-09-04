"""Configurazione: indirizzi, sezioni e parametri della piattaforma JCityGov."""

import os

# Indirizzo base dell'installazione JCityGov dell'ente.
BASE_URL = os.environ.get(
    "ALBO_BASE_URL", "https://albopretorio.comune.cittadicastello.pg.it"
).rstrip("/")

# Nome visualizzato dell'ente.
ENTE = os.environ.get("ALBO_ENTE", "Comune di Città di Castello")

# Sezioni dell'albo (pagine Liferay sotto /web/trasparenza/).
SEZIONI = {
    "papca-ap": "Albo pretorio (atti in pubblicazione)",
    "papca-p": "Storico atti (delibere, determine, ordinanze, decreti)",
    "papca-pm": "Pubblicazioni di matrimonio",
}
SEZIONE_PREDEFINITA = os.environ.get("ALBO_SEZIONE", "papca-ap")

# Identificativo del portlet Liferay che genera le liste.
PORTLET_ID = "jcitygovalbopubblicazioni_WAR_jcitygovalbiportlet"
PREFISSO_PARAM = "_" + PORTLET_ID + "_"

# Percorso della pagina di sezione e del dettaglio di un atto.
PERCORSO_SEZIONE = "/web/trasparenza/{sezione}"
PERCORSO_DETTAGLIO = "/web/trasparenza/{sezione}/-/papca/display/{id}"

# Rete: user agent, timeout e pausa tra le richieste (educazione verso il server).
USER_AGENT = os.environ.get(
    "ALBO_USER_AGENT",
    "AlboPretorioEstrattore/1.0 (+https://github.com/mariosca/ipod2)",
)
TIMEOUT = float(os.environ.get("ALBO_TIMEOUT", "30"))
PAUSA = float(os.environ.get("ALBO_PAUSA", "0.25"))
MAX_PAGINE = int(os.environ.get("ALBO_MAX_PAGINE", "500"))
RIGHE_PER_PAGINA = int(os.environ.get("ALBO_RIGHE_PER_PAGINA", "75"))
THREAD_DETTAGLI = int(os.environ.get("ALBO_THREAD_DETTAGLI", "4"))

# Archivio locale (SQLite).
PERCORSO_DB = os.environ.get(
    "ALBO_DB",
    os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "albo.sqlite"),
)


def url_sezione(sezione: str, base_url: str = BASE_URL) -> str:
    return base_url + PERCORSO_SEZIONE.format(sezione=sezione)


def url_dettaglio(sezione: str, id_atto: str, base_url: str = BASE_URL) -> str:
    return base_url + PERCORSO_DETTAGLIO.format(sezione=sezione, id=id_atto)


def url_export_csv(sezione: str, base_url: str = BASE_URL) -> str:
    """URL della risorsa "exportList" del portlet, che restituisce l'elenco in CSV."""
    p = PREFISSO_PARAM
    return (
        url_sezione(sezione, base_url)
        + "?p_p_id=" + PORTLET_ID
        + "&p_p_lifecycle=2&p_p_state=normal&p_p_mode=view"
        + "&p_p_resource_id=exportList&p_p_cacheability=cacheLevelPage"
        + "&p_p_col_id=column-1&p_p_col_count=1"
        + "&" + p + "format=csv"
        + "&" + p + "action=mostraLista"
        + "&" + p + "resetFilter=true"
    )


def url_pagina_lista(sezione: str, pagina: int, righe: int, base_url: str = BASE_URL) -> str:
    """URL di una pagina dell'elenco, con i parametri standard del SearchContainer Liferay."""
    p = PREFISSO_PARAM
    return (
        url_sezione(sezione, base_url)
        + "?p_p_id=" + PORTLET_ID
        + "&p_p_lifecycle=0&p_p_state=normal&p_p_mode=view"
        + "&p_p_col_id=column-1&p_p_col_count=1"
        + "&" + p + "delta=" + str(righe)
        + "&" + p + "cur=" + str(pagina)
        + "&" + p + "resetCur=false"
    )
