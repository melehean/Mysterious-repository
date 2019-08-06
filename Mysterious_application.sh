#!/bin/bash
#Author:                    Michal Sieczczynski 175989	
#Created on:		        25.05.2019
#Last Modified by:	        Michal Sieczczynski
#Last Modified on:	        30.05.2019
#Version:		            1.0
#
#Description:
#Mysterious application to aplikacja zajmujaca sie szyfrowaniem i deszyfrowaniem plikow.
#Glownym zalozeniem tego projektu jest przedstawienie opcji z programu szyfrujacego GNUPG
#GNU Privacy Guard w przyjaznym dla uzytkownika srodowisku graficznym.
#
#Licensed under GPL (see /usr/share/common-licenses/GPL for more details
#or contact # the Free Software Foundation for a copy

#-----------------------------------------------------------------------------------------

VERSION="1.0"
OPT=""
KOMENDA_G=""
#--------------
TABLICA_ID=()
KLUCZE_DANE_UZYTKOWNIKA=()
TABLICA_DANE=()
TABLICA_LISTA_KLUCZY=()
#--------------

#-----------------------------------------------------------------------------------------

    pokaz_menu()
    {
        MENU=("1. Wygeneruj nowy klucz"
              "2. Zaszyfruj plik szyfrem asymetrycznym"
              "3. Zaszyfruj plik szyfrem symetrycznym"  
              "4. Deszyfruj plik"
              "5. Eksportuj klucz"
              "6. Importuj klucz"
              "7. Usun klucz"
              "8. Zakończ program"
             )
        KOMENDA_G=`zenity --list --column=Menu "${MENU[@]}" --width 400 --height 400 --title "Mysterious application"` #wybranie opcji
    }
    # --batch - batch mode, gpg nie wypisuje zapytan w konsoli; --yes - na wiekszosc odpowiada Y, przydatne np. gdy chcemy nadpisac plik
    stworz_liste_kluczy() #mega wazna funkcja do zapisywania danych z listy kluczy publicznych do tablic
    {    
	#jezeli poprzednio bylo jeszcze cos w tablicy to musze to usunac w przeciwnym wypadku np. po usunieciu klucza bede mogl ponownie nim szyforwac, co jest niedopuszczalne        
	    unset TABLICA_ID[*]  
        unset KLUCZE_DANE_UZYTKOWNIKA[*]
        unset TABLICA_LISTA_KLUCZY[*]  
        unset TABLICA_DANE[*]  
	#lista kluczy publicznych w batch mode | biore tylko publiczne nie subklucze czy dane uzytkownikow | ucinam, zeby miec tylko ID klucza 
	#biore tylko te, ktore zaczynaja sie na liczbe (na poczatku jest dlugosc klucza, wiec bedzie gralo) | ucinam dlugosc klucza, zeby zostal sam ID
        TABLICA_ID=(`gpg --batch --list-key | grep pub | cut -d ' ' -f 4 | grep '^[0-9]' | cut -d '/' -f 2`) 
        KLUCZE_DANE_UZYTKOWNIKA=(`gpg --batch --list-key | grep uid `) #lista kluczy publicznych | biore dane uzytkownika
        DL_KLUCZE_DANE=${#KLUCZE_DANE_UZYTKOWNIKA[*]} #dlugosc tablicy z danymi uzytkownika
        POM=""
        IT=0
        for (( i=0; $i < $DL_KLUCZE_DANE; i++ )) ; do #przechodze po calych danych uzytkownika sa w formie uid DANE uid DANE ... . Dane moga miec rozna ilosc, wiec ta metoda nie powoduje bledu
            if [[ "${KLUCZE_DANE_UZYTKOWNIKA[$i]}" == "uid" ]] #jezeli natrafie na uid
            then
                j=$(($i+1))   
                POM=""             
                until [ "${KLUCZE_DANE_UZYTKOWNIKA[$j]}" == "uid" ] || [ $j -eq $DL_KLUCZE_DANE ]
                do
                     POM="$POM ${KLUCZE_DANE_UZYTKOWNIKA[$j]}" #zapisuje dane do zmiennej, aby wszystkie dane jednego klucza byly w jednej zmiennej
                     j=$(($j+1)) 
                done
                TABLICA_DANE[$IT]="$POM" 
                IT=$(($IT+1))
                i=$(($j-1)) 
            fi
        done
        for (( i=0; $i < ${#TABLICA_ID[*]}; i++ )) ; do
            TABLICA_LISTA_KLUCZY[$i]="$(($i+1)). ${TABLICA_ID[$i]} ${TABLICA_DANE[$i]}" #zapisuje wszystkie dane jednego klucza, zeby byly w jednej glownej tablicy
        done
    }

    usun_klucz()
    {
    stworz_liste_kluczy #biore aktualna liste kluczy
    if [[ ${#TABLICA_ID[@]} -gt 0 ]]
    then
        KOMENDA=""
        until [ -n "$KOMENDA" ] #az uzytkownik cos zaznaczy - zapobiega to bledom, ze uzytkownik nic nie wybierze i dane pojda do funckji gpg
        do
		    #lista kluczy publicznych do wyboru do usuniecia               
		    KOMENDA=`zenity --list --column "Lp ID klucza nazwa uzytkownika (komentarz) <email>" "${TABLICA_LISTA_KLUCZY[@]}" --text "Lista kluczy" --width 400 --height 400 --title "Mysterious application"`
            if [[ $? == "1" ]]
            then
                return
            fi
        done
        OPCJA=${KOMENDA:0:1}; #biore numer klucza na liscie
        OPCJA=$(($OPCJA-1)) #odejmuje 1, bo tablice numerujemy od 0
        CZY_PRYWATNY=`gpg --list-secret-key | grep "${TABLICA_ID[$OPCJA]}"` #sprawdzam czy dany klucz publiczny jest polaczony z jakims prywatnym
        if [[ -n "$CZY_PRYWATNY" ]] #jezeli klucz publiczny jest polaczony z prywatnym
        then
            #odcisk palca po ID klucza publicznego (prywanty ma to samo ID) | linia zawierajaca fingerprint = ... (albo podobnie) | biore tylko to, co jest po = | usuwam spacje, bo inaczej nie zadziala
	        ODCISK_PALCA=`gpg --fingerprint "${TABLICA_ID[$OPCJA]}" | grep fingerprint | cut -d '=' -f 2 | tr -d ' '` #pobieram odcisk palca klucza 
            gpg --batch --yes --delete-secret-key "$ODCISK_PALCA" #usuwam klucz prywatny - klucz prywanty moge usunac z batch mode tylko poprzez fingerprint
            gpg --batch --yes --delete-key "${TABLICA_ID[$OPCJA]}" #usuwam klucz publiczny po jego ID
            zenity --info --title "Sukces" --text "Usunieto klucz prywatny i publiczny" --width 200 #informacja od sukcesie
        else
            gpg --batch --yes --delete-key "${TABLICA_ID[$OPCJA]}" #jezeli klucz publiczny nie ma klucza prywantego (np. pochodzi z importu) to usuwam tylko klucz publiczny
            zenity --info --title "Sukces" --text "Usunieto klucz publiczny" --width 200 #informacja o sukcesie
        fi
    else 
         zenity --info --title "Cos nie tak" --text "NAJPIERW MUSISZ WYGENEROWAC KLUCZ" --width 200
    fi 
    }

    importuj_klucz()
    {
	    stworz_liste_kluczy #biore aktualna liste kluczy
	    DL_1=${#TABLICA_LISTA_KLUCZY[*]} #zapisuje ilosc kluczy do zmiennej - przyda sie przy sprawdzaniu czy klucz sie zaimportowal
	    PLIK=""
        until [ -n "$PLIK" ] #uzytkownik ma wpisac nazwe pliku do importu - petla zapobiega pustej nazwie pliku
        do
           PLIK=`zenity --entry --title "Plik z kluczem do importu" --text "Podaj nazwe pliku:"`
           if [[ $? == "1" ]]
           then
                return
           fi
        done
	    if [[ -f "$PLIK" ]] #jezlei plik istnieje
        then 
           gpg --batch --yes --import "$PLIK" #imporuje klucz
	       stworz_liste_kluczy #uaktualniam liste kluczy
	       DL_2=${#TABLICA_LISTA_KLUCZY[*]} #pobieram aktualna ilosc kluczy
	       if [[ DL_2 -gt DL_1 ]] #jezeli klucz sie dodal - jest wiecej kluczy na liscie niz bylo wczesniej
		   then
			    zenity --info --title "Sukces" --text "Import zakonczony sukcesem" --width 200 #informacja o sukcesie
		   else
			    zenity --info --title "Cos nie tak" --text "IMPORT ZAKONCZONY NIEPOWODZENIEM" --width 200 #informacja o niepowodzeniu
		   fi
        else
            zenity --info --title "Cos nie tak" --text "PLIK NIE ISTNIEJE" --width 200 #informacja o bledzie
        fi  
    }

    eksportuj_klucz()
    {
	stworz_liste_kluczy #biore aktualna liste kluczy
    if [[ ${#TABLICA_ID[@]} -gt 0 ]]
    then
	    KOMENDA=""
        until [ -n "$KOMENDA" ] #az uzytkownik cos zaznaczy - zapobiega to bledom, ze uzytkownik nic nie wybierze i dane pojda do funckji gpg
        do              
		    KOMENDA=`zenity --list --column "Lp ID klucza nazwa uzytkownika (komentarz) <email>" "${TABLICA_LISTA_KLUCZY[@]}" --text "Lista kluczy" --width 400 --height 400 --title "Mysterious application"`
            if [[ $? == "1" ]]
            then
                return
            fi
        done
        OPCJA=${KOMENDA:0:1}; #pobieram numer klucza
        OPCJA=$(($OPCJA-1)) #odejmuje 1, bo liczymy od 0 w tablicy
	    PLIK=""
        until [ -n "$PLIK" ] #pobieram nazwe pliku, ktory bedzie zawieral eksportowany klucz - plik musi byc pusty, badz moze nie istniec, wtedy tworze nowy plik
        do
           PLIK=`zenity --entry --title "Plik, ktory bedzie zawieral eksportowany klucz" --text "Podaj nazwe pliku ( plik musi byc pusty ):"`
           if [[ $? == "1" ]]
           then
               return
           fi
        done
	    if [[ ! -e "$PLIK" ]] || [[ ! -s "$PLIK" ]] #jezeli plik nie instnieje lub jest pusty
        then
		    if [[ ! -e "$PLIK" ]] #jezeli plik nie istnieje
		    then
			    touch "$PLIK" #tworze nowy plik
		    fi
            gpg --yes --batch --output "$PLIK" --export "${TABLICA_ID[$OPCJA]}" #eksportuje klucz za pomoca batch mode
            if [[ -s "$PLIK" ]] #jezeli plik bedzie cos zawieral po eksporcie to znaczy, ze eksport sie powiodl
            then
                    zenity --info --title "Sukces" --text "Eksport sie powiodl" --width 300
            else #jezeli plik dalej bedzie pusty to znaczy, ze eksport sie nie powiodl
                    zenity --info --title "Cos nie tak" --text "EKSPORT ZAKONCZONY NIEPOWODZENIEM" --width 300
            fi
       else #jezeli plik istnieje i nie jest pusty
            zenity --info --title "Cos nie tak" --text "PLIK NIE JEST PUSTY" --width 300
       fi  
    else 
        zenity --info --title "Cos nie tak" --text "NAJPIERW MUSISZ WYGENEROWAC KLUCZ" --width 200
    fi  

    }

    szyfruj_symetrycznie() #szyfrowanie niewykorzystujace klucza do szyfrowania - szyfruje za pomoca podanego hasla
    {
        PLIK=""
        until [ -n "$PLIK" ] #pobieram plik, standardowo, aby wykluczyc pusta nazwe pliku	``		
        do
             PLIK=`zenity --entry --title "Plik do szyfrowania symetrycznego" --text "Podaj nazwe pliku:"`
             if [[ $? == "1" ]]
             then
                  return
             fi
        done
        if [[ -f "$PLIK" ]] #jezeli plik istnieje
        then 
                HASLO=""
                until [ -n "$HASLO" ] #pobieram haslo do pliku + petla
                do
                    HASLO=`zenity --password --title "Haslo" --text "Podaj haslo do szyfrowania symetrycznego:"`
                    if [[ $? == "1" ]]
                    then
                         return
                    fi
                done 
                ALGORYTM=""  
                until [ -n "$ALGORYTM" ] #pobieram algorytm + petla, sa 3 algorytmy do wyboru
                do
                 ALGORYTM=`zenity --list --radiolist --title "Algorytmy do szyfrowania symetrycznego" --text "Wybierz algorytm:" --column "" FALSE "AES256" --column "" FALSE "TWOFISH"  FALSE "CAMELLIA256" --width 400 --height 400`
                    if [[ $? == "1" ]]
                    then
                        return
                    fi
                done             
                gpg --batch --yes --symmetric --cipher-algo "$ALGORYTM" --passphrase="$HASLO" "$PLIK" #szyfruje symetrycznie w batch mode
		if [[ -f "$PLIK.gpg" ]] #jezeli szyfrowanie sie udalo to powinien utworzyc sie plik z rozszerzeniem gpg, ktory bedzie zawieral zaszyfrowany plik i tu sprawdzam czy taki plik sie utworzyl
                then
           	    zenity --info --title "Sukces" --text "Udalo sie - Twoje dane sa bezpieczne" --width 200 #jesli sie utworzyl to sukces dobrze wszystko sie zaszyfrowalo
                else
            	    zenity --info --title "Cos nie tak" --text "SZYFROWANIE NIE POWIODLO SIE" --width 200 #jak nie to cos nie tak
                fi
        else
            zenity --info --title "Cos nie tak" --text "PLIK NIE ISTNIEJE" --width 200 #blad plik nie istnieje
        fi        
    }

    deszyfruj()
    {
        PLIK_OD="" #plik do odszyfrowywania
        until [ -n "$PLIK_OD" ] #pobieram nazwe pliku i zapobiegam pustej nazwie
        do
              PLIK_OD=`zenity --entry --title "Plik do odszyfrowania" --text "Podaj sciezke do pliku, ktory chesz odszyfrowac ( bez rozszerzenia .gpg - dopisze je za Ciebie ):"`
              if [[ $? == "1" ]]
              then
                return
              fi
        done
        PLIK_OD="$PLIK_OD.gpg" #dopisuje .gpg do nazwy pliku, bo kazdy plik z zaszyfrowana wiadomoscia bedzie mial takie rozszerzenie, robie to ja w celach bezpieczenstwa
                                # gdyby to robil uzytkownik to jak poda plik bez tego rozszerzenia to bedzie blad, wiec lepiej dbac o bezpieczenstwo
        if [[ -f "$PLIK_OD" ]] #patrze czy istnieje plik
        then
            PLIK_NOWY=""
            until [ -n "$PLIK_NOWY" ] #pobieram plik, w ktorym ma sie znajdowac zaszyfrowana wiadomosc
            do
                PLIK_NOWY=`zenity --entry --title "Plik z wiadomoscia" --text "Podaj nazwe pliku, w ktory ma byc zapisana odszyfrowana wiadomosc ( plik musi byc pusty ):"`
                if [[ $? == "1" ]]
                then
                     return
                fi
            done
            if [[ ! -e "$PLIK_NOWY" ]] || [[ ! -s "$PLIK_NOWY" ]] #jezeli plik nie istnieje lub nie jest pusty
            then
		        if [[ ! -e "$PLIK_NOWY" ]] #jezeli plik nie istnieje
		        then
			        touch "$PLIK_NOWY" #tworze nowy
		        fi
                HASLO=""
                until [ -n "$HASLO" ] #pobieram haslo dostepu do klucza + petla
                do
                       HASLO=`zenity --password --title "Haslo" --text "Podaj haslo:"`
                       if [[ $? == "1" ]]
                       then
                           return
                       fi
                done
                gpg --yes --batch --output "$PLIK_NOWY" --passphrase="$HASLO" "$PLIK_OD" #deszyfrowanie
                if [[ -s "$PLIK_NOWY" ]] #sprawdzam czy cos zostalo zapisane w pliku, w ktorym miala zostac zapisana wiadomosc
                then
                    zenity --info --title "Sukces" --text "Mozesz zajrzec, jakie sekrety skrywa odszyfrowany plik ;)" --width 300 #jesli tak - sukces
                else
                    zenity --info --title "Cos nie tak" --text "PLIK JEST PUSTY - ZAPEWNE ZLE WPISANO HASLO BADZ UPEWNIJ SIE, ZE DANY KLUCZ NIE POCHODZI Z IMPORTU" --width 300 #jesli nie cos jest nie tak
                fi
            else
                zenity --info --title "Cos nie tak" --text "PLIK NIE JEST PUSTY" --width 300 #jezeli w danym pliku juz cos bylo - uzytkownik klamal
            fi        
            
        else
            zenity --info --title "Cos nie tak" --text "PLIK NIE ISTNIEJE" --width 200 #jezeli podany plik nie istnieje
        fi
    }

    szyfruj_asymetrycznie()
    {
    stworz_liste_kluczy #biore aktualna liste kluczy
    if [[ ${#TABLICA_ID[@]} -gt 0 ]]
    then  
	    KOMENDA=""
        until [ -n "$KOMENDA" ] #az uzytkownik cos zaznaczy - zapobiega to bledom, ze uzytkownik nic nie wybierze i dane pojda do funckji gpg
        do              
		    KOMENDA=`zenity --list --column "Lp ID klucza nazwa uzytkownika (komentarz) <email>" "${TABLICA_LISTA_KLUCZY[@]}" --text "Lista kluczy" --width 400 --height 400 --title "Mysterious application"`
            if [[ $? == "1" ]]
            then
                return
            fi
        done
        if [[ $? == "1" ]]
        then
           return
        fi
        OPCJA=${KOMENDA:0:1}; #pobieram numer klucza na liscie
        OPCJA=$(($OPCJA-1)) #odejmuje 1, bo numerujemy tablice od 0
	    PLIK=""
	    until [ -n "$PLIK" ] #pobieram plik, ktory uzytkownik chce zaszyfrowac
        do
           PLIK=`zenity --entry --title "Plik do zaszyfrowania" --text "Podaj sciezke do pliku, ktory chesz zaszyfrowac:"`
           if [[ $? == "1" ]]
           then
            return
           fi
        done
        if [[ -f "$PLIK" ]] #jezeli plik isnieje
        then
            gpg --batch -r "${TABLICA_ID[$OPCJA]}" --yes --trust-model always --encrypt "$PLIK" #szyfruje go w batch mode i ustawiam zaufanie, zeby mozna bylo tez szyfrowac kluczami z importu
	        if [[ -f "$PLIK.gpg" ]] #jezeli powstal zaszyfrowany plik
            then
           	    zenity --info --title "Sukces" --text "Udalo sie - Twoje dane sa bezpieczne" --width 200 #udalo sie poprawnie zaszyfrowac
            else
            	zenity --info --title "Cos nie tak" --text "SZYFROWANIE NIE POWIODLO SIE" --width 200 #nie wyszlo
            fi
        else
            zenity --info --title "Cos nie tak" --text "PLIK NIE ISTNIEJE" --width 200 #plik nie istnieje
        fi
    else
        zenity --info --title "Cos nie tak" --text "NAJPIERW MUSISZ WYGENEROWAC KLUCZ" --width 200
    fi
    }

    obsluz_daty()
    {
             CZAS_OKRES=$1 #spisanie wartosci poczatkowych z argumentow funckji 
             ILE=$2
             CZAS_A=$3
             CZAS_MENU=$4               
        CZAS_OKRES=`zenity --list --radiolist --title "Czas waznosci klucza" --text "Wybierz okres waznosci:" --column "" FALSE "Lata" --column "" FALSE "Miesiace" FALSE "Tygodnie"  FALSE "Dnie" FALSE "Bez daty waznosci" --width 400 --height 400` #4 radiobuttony okreslajace jaki okres interesuje uzytkownika
                # oddzielnie dla poszczegolnych okresow ustawiam dozwolony czas (GPG moze przechowac date do 2105) zarowno dla zapisu do pliku jak i do widoku w menu
                if [[ "$CZAS_OKRES" == "Lata" ]]
		        then
			           ILE=0
                       until [ "$ILE" -gt 0 ] && [ "$ILE" -lt 85 ]
                       do
                            ILE=`zenity --entry --title "Ile lat" --text "Podaj ile lat ma byc wazny klucz:"`
                            if [[ $? == "1" ]]
                            then
                                return
                            fi
                       done
                       CZAS_A="${ILE}y" #do pliku i nizej tak samo
                       CZAS_MENU="w latach: ${ILE}" #do widoku w menu i nizej tak samo
		        fi
                 if [[ "$CZAS_OKRES" == "Miesiace" ]]
		        then
			           ILE=0
                       until [ "$ILE" -gt 0 ] && [ "$ILE" -lt 1020 ]
                       do
                            ILE=`zenity --entry --title "Ile miesiecy" --text "Podaj ile miesiecy ma byc wazny klucz:"`
                       done
                       CZAS_A="${ILE}m"
                       CZAS_MENU="w miesiacach: ${ILE}"
		        fi
                if [[ "$CZAS_OKRES" == "Tygodnie" ]]
		        then
			           ILE=0
                       until [ "$ILE" -gt 0 ] && [ "$ILE" -lt 4420 ]
                       do
                            ILE=`zenity --entry --title "Ile tygodni" --text "Podaj ile tygodni ma byc wazny klucz:"`
                            if [[ $? == "1" ]]
                            then
                                return
                            fi
                       done
                        CZAS_A="${ILE}w"
                        CZAS_MENU="w tygodniach: ${ILE}"
		        fi
                if [[ "$CZAS_OKRES" == "Dnie" ]]
		        then
			           ILE=0
                       until [ "$ILE" -gt 0 ] && [ "$ILE" -lt 30940 ]
                       do
                            ILE=`zenity --entry --title "Ile dni" --text "Podaj ile dni ma byc wazny klucz:"`
                            if [[ $? == "1" ]]
                            then
                                return
                            fi
                       done
                       CZAS_A="${ILE}"
                       CZAS_MENU="w dniach: ${ILE}"
		        fi
                if [[ "$CZAS_OKRES" == "Bez daty waznosci" ]] #jest mozliwosc nie podawania daty waznosci klucza
		        then
			          CZAS_A=0 #wtedy w pliku zapisujemy wartosc 0
                      CZAS_MENU="jest nieograniczony"
		        fi
    }


    wygeneruj_nowy_klucz()
    {
        #zmienne do szyfrowania asymetrycznego - generowanie nowego klucza
        # _A - szyfrowanie asymetryczne
        ALGORYTM_MENU="" #zmienna do przechowywania algorytmu i pokazywania go w menu
        ALGORYTM_SUB="" #zmienna do przechowywania algorytmu do podpisywania
        DL_A="" #dlugosc klucza
        CZAS_A="" #czas, ktory bedzie szedl do pliku
        CZAS_MENU="" #czas, do pokazywania w menu
        NAZWA_A="" #nazwa uzytkownika
        EMAIL_A="" #email uzytkownika
        KOMENTARZ_A="" #komentarz uzytkownika
        HASLO_A="" #haslo uzytkownika, ktore idze do pliku
        HASLO_MENU="Musisz podac haslo" #komunikat o stanie hasla, czy jest zapisane czy nie, bo glupio by bylo pokazywac haslo uzytkownika w menu
        KOMENDA_A="" #do sczytywania, co chce wpisac uzytkownik
        OPCJA_A="0"  #opcja wzieta z komunikatu      
        BRAKUJE="" #czego jeszcze uzytkownik nie wpisal
        while [ "$OPCJA_A" != "9" ] #jezeli nie przechodzimy do glownego menu
        do
            MENU=("1. Algorytm $ALGORYTM_MENU" "2. Dlugosc klucza $DL_A" "3. Czas waznosci klucza $CZAS_MENU" "4. Nazwa uzytkownika $NAZWA_A" 
                    "5. Email $EMAIL_A" "6. Kometarz $KOMENTARZ_A" "7. Haslo $HASLO_MENU" "8. Generuj klucz" "9. Powrot") #wszystkie opcje w tym menu
             KOMENDA_A=`zenity --list --text "Generowanie nowego klucza" --column=Menu "${MENU[@]}" --width 400 --height 400 --title "Mysterious application"` #sczytuje, co chce wpisac uzytkownik
             OPCJA_A=${KOMENDA_A:0:1}; #wydobywam numer polecenia
            if [[ "$OPCJA_A" == "1" ]] #wybor algorytmu
	        then 
                # sa dwa radiobuttony                
                ALGORYTM_MENU=`zenity --list --radiolist --title "Algorytm" --text "Wybierz algorytm:" --column "" FALSE "RSA i RSA" --column "" FALSE "DSA i Elgamal" --width 400 --height 400`
	        fi
            if [[ "$OPCJA_A" == "2" ]] #jezeli dlugosc
	        then 
                if [[ "$ALGORYTM_MENU" == "RSA i RSA" ]] #sprawdzam czy dany algorytm
	            then 
                        DL_A=0; #aby moc zmienic nawet poprawna wartosc
                        until [ "$DL_A" -ge 1024 ] && [ "$DL_A" -le 4096 ] #az dlugosc bedzie miescic sie w dozwolonych ramach
                        do
                            DL_A=`zenity --entry --title "Dlugosc klucza" --text "Podaj dlugosc klucza <1024;4096> :"` #uzytkownik moze wpisywac dlugosc
                        done
                        ALGORYTM_A="RSA" #ustawiam algorytm
                        ALGORYTM_SUB="RSA" #i algorytm do podpisywania
	            fi
                if [[ "$ALGORYTM_MENU" == "DSA i Elgamal" ]] #sprawdzam czy inny algorytm
	            then 
                       DL_A=0;  #aby moc zmienic nawet poprawna wartosc
                       until [ "$DL_A" -ge 1024 ] && [ "$DL_A" -le 3072 ] #az dlugosc bedzie miescic sie w dozwolonych ramach
                       do
                            DL_A=`zenity --entry --title "Dlugosc klucza" --text "Podaj dlugosc klucza <1024;3072> :"` #uzytkownik moze wpisywac dlugosc
                       done
                        ALGORYTM_A="DSA" #ustawiam algorytm
                        ALGORYTM_SUB="ELG-E" #i algorytm do podpisywania Elgamal
	            fi
                if [[ -z "$ALGORYTM_MENU" ]] #dozwolona dlugosc jest zalezna od algorytmu, wiec najpierw trzeba wybrac algorytm
	            then 
                    zenity --info --title "Cos nie tak" --text "NAJPIERW MUSISZ WYBRAC ALGORYTM" --width 400
	            fi 
	        fi
            if [[ "$OPCJA_A" == "3" ]] #jak dlugo od momentu utworzenia ma byc wazny klucz
	        then 
                 CZAS_OKRES="" #zerowanie zmiennych 
                 ILE=0
                 CZAS_A=""
                 CZAS_MENU=""             
                obsluz_daty $CZAS_OKRES $ILE $CZAS_A $CZAS_MENU #funckja do obslugi daty
	        fi            
            if [[ "$OPCJA_A" == "4" ]] #nazwa uzytkownika
	        then 
                NAZWA_A="" #pozwala na zmiane juz istniejacej i poprawnej nazwy
                until [ ${#NAZWA_A} -ge 5 ] #w GPG dozwolone sa tylko nazwy powyzej 5 znakow
                do
                     NAZWA_A=`zenity --entry --title "Nazwa uzytkownika" --text "Podaj nazwe uzytkownika (co najmniej 5 znakow):"`
                done
                
	        fi
            if [[ "$OPCJA_A" == "5" ]] #email
	        then 
                 EMAIL_A="" #pozwala na zmiane emailu
                 until [[ $EMAIL_A = *@* ]] ; #sprawdzam czy email zawiera @ to i tak lepiej niz w GPG, tam email moze byc pusty
                 do
                      EMAIL_A=`zenity --entry --title "Email" --text "Podaj swoj email:"`
                 done
	        fi
            if [[ "$OPCJA_A" == "6" ]] #komentarz
	        then 
                KOMENTARZ_A=`zenity --entry --title "Komentrz" --text "Skomentuj klucz:"` #zapisuje to, co wpisze uzytkownik
	        fi
            if [[ "$OPCJA_A" == "7" ]] #haslo - nie sprawdzam czy jest silne, w GPG moze byc puste
	        then 
                HASLO_A=`zenity --password --title "Haslo" --text "Podaj haslo:"` #zapisuje to, co wpisze uzytkownik
                HASLO_MENU="Haslo zostalo zapisane" #informuje, ze haslo zostalo zapisane
	        fi
            if [[ "$OPCJA_A" == "8" ]]
	        then 
                BRAKUJE="BRAKUJE" #w razie gdyby czegos nie bylo, wszystko jest wymagane, bo potem GPG krzyczy, ze sa puste linie w batch mode
                if [[ -z "$ALGORYTM_A" ]]
	            then 
                    BRAKUJE="${BRAKUJE} ALGORYTMU "
	            fi  
                if [[ -z "$CZAS_A" ]]
	            then 
                    BRAKUJE="${BRAKUJE} CZASU WAZNOSCI "
	            fi  
                if [[ -z "$DL_A" ]]
	            then 
                    BRAKUJE="${BRAKUJE} DLUGOSCI KLUCZA "
	            fi 
                if [[ -z "$NAZWA_A" ]]
	            then 
                    BRAKUJE="${BRAKUJE} NAZWY UZYTKOWNIKA"
	            fi 
                if [[ -z "$EMAIL_A" ]]
	            then 
                    BRAKUJE="${BRAKUJE} EMAILA"
	            fi 
                if [[ -z "$KOMENTARZ_A" ]]
	            then 
                    BRAKUJE="${BRAKUJE} KOMENTARZA"
	            fi 
                if [[ -z "$HASLO_A" ]]
	            then 
                    BRAKUJE="${BRAKUJE} HASLA"
	            fi 
                if [[ "$BRAKUJE" == "BRAKUJE" ]] #jak wszystko jest zapisuje do pliku za pomoca batch mode, aby zrobic to bez zapytan GPG w konsoli
	            then 
                #batch mode zapisuje wszystkie wlasnosci klucza do pliku, %commit zatwierdza podane wlasnosci
                cat > gen_key_pom <<EOF
Key-Type: $ALGORYTM_A
Key-Length: $DL_A
Subkey-Type: $ALGORYTM_SUB
Subkey-Length: $DL_A 
Name-Real: $NAZWA_A
Name-Comment: $KOMENTARZ_A
Name-Email: $EMAIL_A
Expire-Date: $CZAS_A
Passphrase: $HASLO_A
%commit
EOF
                   gpg --batch --quiet --no-tty --gen-key gen_key_pom #nareszcie funckja generujaca klucz
                   zenity --info --title "Sukces" --text "Pomyslnie wygenerowano klucz" --width 400
                   return 
                else
                    zenity --info --title "Cos nie tak" --text "$BRAKUJE" --width 400 #jak czegos brakuje to nie generuje klucza tylko wypisuje, co uzytkwonik ma jeszcze wpisac
                fi
	        fi
        done
    }

#-----------------------------------------------------------------------------------------

while getopts ":hva" opt; do #sczytywanie opcji podanych na wejsciu
    OPT="1"   
    case $opt in
        v)echo "Version: $VERSION">&2;;
        a)echo "Author: Michal Sieczczynski">&2;;
        h)echo "Help:"
echo "Dostepne opcje w glownym menu:"
echo "-Generowanie kluczy - nalezy wypelnic wszyskie pola, algorytmy: dwa do wyboru wystarczy zaznaczyc, dlugosc klucza: najpierw nalezy wybrac algorytm dozwolone przedzialy zostaly opisane,"
echo "czas waznosci klucza: najpierw wybieramy czy chodzi nam o rok, dzien, miesiac, tydzien, a nastepnie ile danych przedzialow czasu ma byc aktywny ten klucz, ograniczenie to 84 lata,"
echo " jest tez opcja braku daty waznosci, nazwa uzytkownika: ma byc co najmniej 5 znakow moga byc spacje, email: ma zawierac @, najlepiej podac prawdziwy, komentarz: mozna pochwalic moja ladna aplikacje ;)"
echo "haslo: niepuste, klikamy Generuj klucz, aby wygenerowac klucz badz Powrot jak jednak sie rozmyslilismy, wtedy wszystkie dane zostana utracone"
echo "-Zaszyfruj plik szyfrem asymetrycznym - musimy wybrac z listy kluczy, jakim kluczem publicznym chcemy zaszyfrowac dany plik i nazwe tego pliku, plik musi istniec, lista kluczy musi byc niepusta, mozemy szyfrowac kluczem pochodzacym z importu"
echo "-Zaszyfruj plik szyfrem symetrycznym - wybieramy algorytm plik i haslo, ten rodzaj szyfrowania nie wykorzystuje kluczy"
echo "-Deszyfruj plik - mozemy deszyfrowac pliki zarowno zaszyfrowane szyfrem symetrycznym i asymetrycznym w obu przypadkach podajemy plik, ktory chcemy odszyfrowac, haslo i plik, w ktorym ma byc zapisana"
echo "odszyfrowana wiadomosc, plik ten musi byc pusty, badz moze nie istniec, wtedy tworze nowy plik. Nie mozna deszyfrowac plikow, ktore pochodza z importu, poniewaz aplikacja przewiduje jedynie import klucza publicznego"
echo "-Eksport klucza - wybieramy z listy jaki klucz publiczny chcemy eksportowac, podajemy do jakiego pliku chcemy eksportowac ten klucz, plik ten musi byc pusty, badz moze nie isntiec, wtedy tworze nowy plik"
echo "-Import klucza - wpisujemy nazwe pliku zawierajacego klucz"
echo "-Usun klucz - klikamy dwa razy na kluczu, zeby go usunac, usuwa sie zarowno klucz publiczny jak i prywatny (jesli prywatny istnieje)"
echo "W celu uzyskania informacji o autorze nalezy podac -a"
echo "W celu uzyskania informacji o wersji programu nalezy podac -v"
echo "W celu uzyskania pomocy nalezy podac -h">&2;;
       \?)echo "Opcja nie istnieje">&2;;
    esac
done

if [ "$OPT" == "" ] #jesli byla jakas opcja to nie uruchamiamy okienka dialogowego
then
while [ "$KOMENDA_G" != "8. Zakończ program" ]
do
    pokaz_menu
    case $KOMENDA_G in
        "1"*)wygeneruj_nowy_klucz;;
        "2"*)szyfruj_asymetrycznie;;
        "3"*)szyfruj_symetrycznie;;
        "4"*)deszyfruj;;
	    "5"*)eksportuj_klucz;;
        "6"*)importuj_klucz;;
        "7"*)usun_klucz;;  
    esac
done
fi
