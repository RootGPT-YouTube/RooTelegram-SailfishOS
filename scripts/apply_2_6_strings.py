#!/usr/bin/env python3
"""Applica le traduzioni delle NUOVE stringhe della 2.6 ai .ts (it/de/pl/ru/fr/sk).

Patcha SOLO i <translation type="unfinished"> il cui <source> è nella tabella,
sostituendoli con la traduzione e togliendo type="unfinished". en.ts: testo=source.
Le voci vanno poi ripiegate nei dict permanenti (apply_translations.py /
translate_*.py) in un secondo momento; qui patchiamo direttamente per la 2.6.
"""
from pathlib import Path
import re
from xml.sax.saxutils import escape, unescape

ORDER = ["it", "de", "pl", "ru", "fr", "sk"]

# source -> (it, de, pl, ru, fr, sk)
T = {
"App permissions": ("Permessi dell'app","App-Berechtigungen","Uprawnienia aplikacji","Разрешения приложения","Autorisations de l'application","Povolenia aplikácie"),
"Manage": ("Gestisci","Verwalten","Zarządzaj","Управление","Gérer","Spravovať"),
"Choose which device resources (location, camera, microphone, contacts, files) RooTelegram is allowed to use.": (
 "Scegli a quali risorse del dispositivo (posizione, fotocamera, microfono, contatti, file) RooTelegram può accedere.",
 "Wähle, welche Geräteressourcen (Standort, Kamera, Mikrofon, Kontakte, Dateien) RooTelegram nutzen darf.",
 "Wybierz, z których zasobów urządzenia (lokalizacja, aparat, mikrofon, kontakty, pliki) może korzystać RooTelegram.",
 "Выберите, какие ресурсы устройства (местоположение, камера, микрофон, контакты, файлы) может использовать RooTelegram.",
 "Choisissez les ressources de l'appareil (localisation, caméra, micro, contacts, fichiers) que RooTelegram peut utiliser.",
 "Vyberte, ktoré zdroje zariadenia (poloha, fotoaparát, mikrofón, kontakty, súbory) môže RooTelegram používať."),
"Turn off the resources you don't want RooTelegram to use. This only blocks the app internally — to fully revoke a system permission use the SailfishOS Settings.": (
 "Disattiva le risorse che non vuoi far usare a RooTelegram. Questo blocca solo l'app internamente — per revocare del tutto un permesso di sistema usa le Impostazioni di SailfishOS.",
 "Schalte die Ressourcen aus, die RooTelegram nicht nutzen soll. Das blockiert nur die App intern — um eine Systemberechtigung vollständig zu entziehen, nutze die SailfishOS-Einstellungen.",
 "Wyłącz zasoby, z których RooTelegram nie ma korzystać. To blokuje tylko wewnątrz aplikacji — aby całkowicie cofnąć uprawnienie systemowe, użyj Ustawień SailfishOS.",
 "Отключите ресурсы, которые RooTelegram не должен использовать. Это блокирует только внутри приложения — чтобы полностью отозвать системное разрешение, откройте Настройки SailfishOS.",
 "Désactivez les ressources que vous ne voulez pas que RooTelegram utilise. Cela bloque seulement en interne — pour révoquer totalement une autorisation système, utilisez les Réglages de SailfishOS.",
 "Vypnite zdroje, ktoré RooTelegram nemá používať. Toto blokuje len v rámci aplikácie — na úplné odobratie systémového povolenia použite Nastavenia SailfishOS."),
"Sensors and personal data": ("Sensori e dati personali","Sensoren und persönliche Daten","Czujniki i dane osobowe","Датчики и личные данные","Capteurs et données personnelles","Senzory a osobné údaje"),
"Safe to turn off: only the related feature stops working, the rest of the app keeps running normally.": (
 "Sicuri da disattivare: si ferma solo la funzione collegata, il resto dell'app continua a funzionare.",
 "Sicher abzuschalten: nur die zugehörige Funktion hört auf zu arbeiten, der Rest der App läuft normal weiter.",
 "Bezpieczne do wyłączenia: przestaje działać tylko powiązana funkcja, reszta aplikacji działa normalnie.",
 "Безопасно отключать: перестаёт работать только связанная функция, остальное приложение работает как обычно.",
 "Sans risque à désactiver : seule la fonction concernée s'arrête, le reste de l'application continue normalement.",
 "Bezpečné vypnúť: prestane fungovať len súvisiaca funkcia, zvyšok aplikácie beží normálne."),
"Location": ("Posizione","Standort","Lokalizacja","Местоположение","Localisation","Poloha"),
"Attaching your location and inline bots that request it.": (
 "Allegare la tua posizione e i bot inline che la richiedono.",
 "Anhängen deines Standorts und Inline-Bots, die ihn anfordern.",
 "Załączanie Twojej lokalizacji oraz boty inline, które jej wymagają.",
 "Прикрепление вашего местоположения и инлайн-боты, которые его запрашивают.",
 "Joindre votre localisation et les bots en ligne qui la demandent.",
 "Pripájanie vašej polohy a inline boty, ktoré ju vyžadujú."),
"Camera": ("Fotocamera","Kamera","Aparat","Камера","Caméra","Fotoaparát"),
"Video during calls.": ("Video durante le chiamate.","Video während Anrufen.","Wideo podczas połączeń.","Видео во время звонков.","Vidéo pendant les appels.","Video počas hovorov."),
"Microphone": ("Microfono","Mikrofon","Mikrofon","Микрофон","Micro","Mikrofón"),
"Voice messages and audio during calls.": (
 "Messaggi vocali e audio durante le chiamate.","Sprachnachrichten und Audio während Anrufen.","Wiadomości głosowe i dźwięk podczas połączeń.","Голосовые сообщения и звук во время звонков.","Messages vocaux et audio pendant les appels.","Hlasové správy a zvuk počas hovorov."),
"Contacts": ("Contatti","Kontakte","Kontakty","Контакты","Contacts","Kontakty"),
"Synchronizing your address book with Telegram.": (
 "Sincronizzare la tua rubrica con Telegram.","Dein Adressbuch mit Telegram synchronisieren.","Synchronizacja książki adresowej z Telegramem.","Синхронизация адресной книги с Telegram.","Synchroniser votre carnet d'adresses avec Telegram.","Synchronizácia adresára s Telegramom."),
"Photos, videos and files": ("Foto, video e file","Fotos, Videos und Dateien","Zdjęcia, filmy i pliki","Фото, видео и файлы","Photos, vidéos et fichiers","Fotky, videá a súbory"),
"Turn off with caution: these are needed to attach and send media. With one off you won't be able to pick that kind of file to send.": (
 "Disattiva con cautela: servono per allegare e inviare media. Disattivandone uno non potrai più scegliere quel tipo di file da inviare.",
 "Mit Vorsicht abschalten: diese werden zum Anhängen und Senden von Medien benötigt. Ist eine aus, kannst du diesen Dateityp nicht mehr zum Senden auswählen.",
 "Wyłączaj ostrożnie: są potrzebne do załączania i wysyłania multimediów. Po wyłączeniu nie wybierzesz tego typu pliku do wysłania.",
 "Отключайте с осторожностью: они нужны для прикрепления и отправки медиа. Если отключить, вы не сможете выбрать такой тип файла для отправки.",
 "À désactiver avec prudence : nécessaires pour joindre et envoyer des médias. Si désactivé, vous ne pourrez plus choisir ce type de fichier à envoyer.",
 "Vypínajte opatrne: sú potrebné na pripájanie a odosielanie médií. Po vypnutí nebudete môcť vybrať tento typ súboru na odoslanie."),
"Images": ("Immagini","Bilder","Obrazy","Изображения","Images","Obrázky"),
"Picking photos to send or to set as profile/story.": (
 "Scegliere foto da inviare o da impostare come profilo/storia.","Fotos auswählen zum Senden oder als Profil/Story.","Wybieranie zdjęć do wysłania lub ustawienia jako profil/relacja.","Выбор фото для отправки или для профиля/истории.","Choisir des photos à envoyer ou à définir comme profil/story.","Výber fotiek na odoslanie alebo nastavenie ako profil/príbeh."),
"Videos": ("Video","Videos","Filmy","Видео","Vidéos","Videá"),
"Picking videos to send or to post as a story.": (
 "Scegliere video da inviare o da pubblicare come storia.","Videos auswählen zum Senden oder als Story.","Wybieranie filmów do wysłania lub opublikowania jako relacja.","Выбор видео для отправки или публикации в истории.","Choisir des vidéos à envoyer ou à publier en story.","Výber videí na odoslanie alebo zverejnenie ako príbeh."),
"Documents and files": ("Documenti e file","Dokumente und Dateien","Dokumenty i pliki","Документы и файлы","Documents et fichiers","Dokumenty a súbory"),
"Picking arbitrary files to send as documents.": (
 "Scegliere file qualsiasi da inviare come documenti.","Beliebige Dateien auswählen zum Senden als Dokumente.","Wybieranie dowolnych plików do wysłania jako dokumenty.","Выбор любых файлов для отправки как документы.","Choisir des fichiers quelconques à envoyer comme documents.","Výber ľubovoľných súborov na odoslanie ako dokumenty."),
"System permissions": ("Permessi di sistema","Systemberechtigungen","Uprawnienia systemowe","Системные разрешения","Autorisations système","Systémové povolenia"),
"Internet access and other low-level permissions are required for the app to work at all and are managed by SailfishOS. To revoke them, open the system Settings → Apps → RooTelegram.": (
 "L'accesso a Internet e altri permessi di basso livello sono indispensabili al funzionamento dell'app e sono gestiti da SailfishOS. Per revocarli, apri Impostazioni di sistema → App → RooTelegram.",
 "Internetzugriff und andere systemnahe Berechtigungen sind für die App unverzichtbar und werden von SailfishOS verwaltet. Zum Entziehen öffne die System-Einstellungen → Apps → RooTelegram.",
 "Dostęp do internetu i inne uprawnienia niskiego poziomu są niezbędne do działania aplikacji i są zarządzane przez SailfishOS. Aby je cofnąć, otwórz Ustawienia systemu → Aplikacje → RooTelegram.",
 "Доступ в интернет и другие низкоуровневые разрешения необходимы для работы приложения и управляются SailfishOS. Чтобы отозвать их, откройте Настройки системы → Приложения → RooTelegram.",
 "L'accès à Internet et d'autres autorisations de bas niveau sont indispensables au fonctionnement de l'application et sont gérés par SailfishOS. Pour les révoquer, ouvrez Réglages système → Applications → RooTelegram.",
 "Prístup na internet a ďalšie nízkoúrovňové povolenia sú nevyhnutné pre chod aplikácie a spravuje ich SailfishOS. Na ich odobratie otvorte Nastavenia systému → Aplikácie → RooTelegram."),
"Image access is turned off in RooTelegram settings.": (
 "L'accesso alle immagini è disattivato nelle impostazioni di RooTelegram.","Der Bildzugriff ist in den RooTelegram-Einstellungen ausgeschaltet.","Dostęp do obrazów jest wyłączony w ustawieniach RooTelegram.","Доступ к изображениям отключён в настройках RooTelegram.","L'accès aux images est désactivé dans les réglages de RooTelegram.","Prístup k obrázkom je vypnutý v nastaveniach RooTelegram."),
"Video access is turned off in RooTelegram settings.": (
 "L'accesso ai video è disattivato nelle impostazioni di RooTelegram.","Der Videozugriff ist in den RooTelegram-Einstellungen ausgeschaltet.","Dostęp do filmów jest wyłączony w ustawieniach RooTelegram.","Доступ к видео отключён в настройках RooTelegram.","L'accès aux vidéos est désactivé dans les réglages de RooTelegram.","Prístup k videám je vypnutý v nastaveniach RooTelegram."),
"Microphone is turned off in RooTelegram settings.": (
 "Il microfono è disattivato nelle impostazioni di RooTelegram.","Das Mikrofon ist in den RooTelegram-Einstellungen ausgeschaltet.","Mikrofon jest wyłączony w ustawieniach RooTelegram.","Микрофон отключён в настройках RooTelegram.","Le micro est désactivé dans les réglages de RooTelegram.","Mikrofón je vypnutý v nastaveniach RooTelegram."),
"File access is turned off in RooTelegram settings.": (
 "L'accesso ai file è disattivato nelle impostazioni di RooTelegram.","Der Dateizugriff ist in den RooTelegram-Einstellungen ausgeschaltet.","Dostęp do plików jest wyłączony w ustawieniach RooTelegram.","Доступ к файлам отключён в настройках RooTelegram.","L'accès aux fichiers est désactivé dans les réglages de RooTelegram.","Prístup k súborom je vypnutý v nastaveniach RooTelegram."),
"Camera is turned off in RooTelegram settings.": (
 "La fotocamera è disattivata nelle impostazioni di RooTelegram.","Die Kamera ist in den RooTelegram-Einstellungen ausgeschaltet.","Aparat jest wyłączony w ustawieniach RooTelegram.","Камера отключена в настройках RooTelegram.","La caméra est désactivée dans les réglages de RooTelegram.","Fotoaparát je vypnutý v nastaveniach RooTelegram."),
"Contacts are turned off in RooTelegram settings.": (
 "I contatti sono disattivati nelle impostazioni di RooTelegram.","Die Kontakte sind in den RooTelegram-Einstellungen ausgeschaltet.","Kontakty są wyłączone w ustawieniach RooTelegram.","Контакты отключены в настройках RooTelegram.","Les contacts sont désactivés dans les réglages de RooTelegram.","Kontakty sú vypnuté v nastaveniach RooTelegram."),
"Still obtaining your position, please wait…": (
 "Sto ancora ottenendo la tua posizione, attendi…","Dein Standort wird noch ermittelt, bitte warten…","Wciąż ustalam Twoją lokalizację, czekaj…","Ещё определяю ваше местоположение, подождите…","Localisation en cours, veuillez patienter…","Stále zisťujem vašu polohu, počkajte…"),
"Telegram doesn't allow granting this permission to all members in this group.": (
 "Telegram non consente di concedere questo permesso a tutti i membri di questo gruppo.","Telegram erlaubt nicht, diese Berechtigung allen Mitgliedern dieser Gruppe zu gewähren.","Telegram nie pozwala nadać tego uprawnienia wszystkim członkom tej grupy.","Telegram не позволяет выдать это разрешение всем участникам этой группы.","Telegram n'autorise pas à accorder cette permission à tous les membres de ce groupe.","Telegram neumožňuje udeliť toto povolenie všetkým členom tejto skupiny."),
"— or —": ("— oppure —","— oder —","— lub —","— или —","— ou —","— alebo —"),
"Log in by QR code": ("Accedi con QR code","Mit QR-Code anmelden","Zaloguj się kodem QR","Войти по QR-коду","Se connecter par QR code","Prihlásiť sa QR kódom"),
"Scan this QR code": ("Scansiona questo QR code","Scanne diesen QR-Code","Zeskanuj ten kod QR","Отсканируйте этот QR-код","Scannez ce QR code","Naskenujte tento QR kód"),
"On a phone already logged into Telegram, open Settings → Devices → Link Desktop Device and scan this code.": (
 "Su un telefono già connesso a Telegram, apri Impostazioni → Dispositivi → Collega dispositivo desktop e scansiona questo codice.",
 "Öffne auf einem bereits bei Telegram angemeldeten Telefon Einstellungen → Geräte → Desktop-Gerät verknüpfen und scanne diesen Code.",
 "Na telefonie już zalogowanym do Telegrama otwórz Ustawienia → Urządzenia → Podłącz urządzenie i zeskanuj ten kod.",
 "На телефоне, уже вошедшем в Telegram, откройте Настройки → Устройства → Подключить устройство и отсканируйте этот код.",
 "Sur un téléphone déjà connecté à Telegram, ouvrez Réglages → Appareils → Lier un ordinateur et scannez ce code.",
 "Na telefóne, ktorý je už prihlásený v Telegrame, otvorte Nastavenia → Zariadenia → Pripojiť zariadenie a naskenujte tento kód."),
"Generating QR code…": ("Generazione del QR code…","QR-Code wird erzeugt…","Generowanie kodu QR…","Создание QR-кода…","Génération du QR code…","Generujem QR kód…"),
"Use phone number instead": ("Usa invece il numero di telefono","Stattdessen Telefonnummer verwenden","Użyj zamiast tego numeru telefonu","Использовать номер телефона","Utiliser plutôt le numéro de téléphone","Použiť radšej telefónne číslo"),
"Stay in chat when closing the app": ("Resta nella chat alla chiusura dell'app","Beim Schließen der App im Chat bleiben","Pozostań w czacie po zamknięciu aplikacji","Оставаться в чате при закрытии приложения","Rester dans la discussion à la fermeture de l'app","Zostať v konverzácii po zatvorení aplikácie"),
"When you close or minimize the app, keep the open chat instead of returning to the home view. Keep this on so an unfinished draft isn't lost when the app closes.": (
 "Quando chiudi o minimizzi l'app, mantieni la chat aperta invece di tornare alla schermata principale. Tienilo attivo per non perdere una bozza non completata alla chiusura dell'app.",
 "Beim Schließen oder Minimieren der App den offenen Chat behalten, statt zur Startansicht zurückzukehren. Lass dies an, damit ein unfertiger Entwurf beim Schließen der App nicht verloren geht.",
 "Po zamknięciu lub zminimalizowaniu aplikacji zachowaj otwarty czat zamiast wracać do ekranu głównego. Zostaw włączone, aby niedokończona wersja robocza nie przepadła przy zamknięciu aplikacji.",
 "При закрытии или сворачивании приложения сохранять открытый чат, а не возвращаться на главный экран. Оставьте включённым, чтобы незавершённый черновик не терялся при закрытии приложения.",
 "Lorsque vous fermez ou réduisez l'application, garder la discussion ouverte au lieu de revenir à l'accueil. Gardez activé pour ne pas perdre un brouillon non terminé à la fermeture de l'application.",
 "Pri zatvorení alebo minimalizovaní aplikácie ponechať otvorenú konverzáciu namiesto návratu na domovskú obrazovku. Nechajte zapnuté, aby sa nedokončený koncept pri zatvorení aplikácie nestratil."),
"Slovak translation by okruhliak. Thanks to everyone helping translate RooTelegram!": (
 "Traduzione slovacca a cura di okruhliak. Grazie a tutti coloro che aiutano a tradurre RooTelegram!",
 "Slowakische Übersetzung von okruhliak. Danke an alle, die bei der Übersetzung von RooTelegram helfen!",
 "Tłumaczenie słowackie: okruhliak. Dziękujemy wszystkim, którzy pomagają tłumaczyć RooTelegram!",
 "Словацкий перевод — okruhliak. Спасибо всем, кто помогает переводить RooTelegram!",
 "Traduction slovaque par okruhliak. Merci à tous ceux qui aident à traduire RooTelegram !",
 "Slovenský preklad: okruhliak. Ďakujeme všetkým, ktorí pomáhajú prekladať RooTelegram!"),
"This project uses the QR Code generator library by Project Nayuki for QR-code login. Thanks for making it available under the conditions of the MIT License!": (
 "Questo progetto usa la libreria QR Code generator di Project Nayuki per l'accesso tramite QR code. Grazie per averla resa disponibile secondo i termini della licenza MIT!",
 "Dieses Projekt verwendet die QR-Code-Generator-Bibliothek von Project Nayuki für die QR-Code-Anmeldung. Danke, dass sie unter den Bedingungen der MIT-Lizenz verfügbar gemacht wurde!",
 "Ten projekt korzysta z biblioteki QR Code generator autorstwa Project Nayuki do logowania kodem QR. Dziękujemy za udostępnienie jej na warunkach licencji MIT!",
 "Этот проект использует библиотеку QR Code generator от Project Nayuki для входа по QR-коду. Спасибо за предоставление её на условиях лицензии MIT!",
 "Ce projet utilise la bibliothèque QR Code generator de Project Nayuki pour la connexion par QR code. Merci de l'avoir mise à disposition selon les termes de la licence MIT !",
 "Tento projekt používa knižnicu QR Code generator od Project Nayuki na prihlásenie QR kódom. Ďakujeme za jej sprístupnenie za podmienok licencie MIT!"),
}

MSG_RE = re.compile(r"<message[^>]*>.*?</message>", re.S)
SRC_RE = re.compile(r"<source>(.*?)</source>", re.S)

def patch(path, lang_index):
    text = path.read_text(encoding="utf-8")
    stats = {"applied": 0, "left": 0}
    def repl(mm):
        block = mm.group(0)
        if 'type="unfinished"' not in block:
            return block
        sm = SRC_RE.search(block)
        if not sm:
            return block
        src = unescape(sm.group(1), {"&quot;": '"', "&apos;": "'"})
        entry = T.get(src)
        if entry is None or lang_index is None:
            tr = src if lang_index is None else None  # en: identity
            if lang_index is not None:
                stats["left"] += 1
                return block
        else:
            tr = entry[lang_index]
        new = "<translation>%s</translation>" % escape(tr, {'"': "&quot;", "'": "&apos;"})
        stats["applied"] += 1
        return re.sub(r'<translation[^>]*>.*?</translation>', new, block, count=1, flags=re.S)
    out = MSG_RE.sub(repl, text)
    path.write_text(out, encoding="utf-8")
    return stats

if __name__ == "__main__":
    root = Path("translations")
    for lang in ORDER:
        st = patch(root / ("harbour-rootelegram-%s.ts" % lang), ORDER.index(lang))
        print(lang, st)
