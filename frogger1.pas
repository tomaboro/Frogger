program frogger;

uses allegro,crt,dos;

const
  //ustawiamy domyslne rozmiary okna
  ScreenWidth= 1000;
  ScreenHeight= 650;
  //dlugosc skoku zaby oraz wysokosc jednego pola
  skok=65;

//typ definiujacy parametry danego podloza
type podloze = record
        //wspolrzedne lewego gornego rogu
        x:integer;
        y:integer;
        //czy na polu mozna stanac
	dang:boolean;
        //wskaznik na bitmape z grafika pola
        pic: AL_BITMAPptr;
        typ:Smallint;
end;

//typ przetrzymujacy informacje o ilosci wystapienia danego pola
type ostatnie_podloze = record
       ile:Smallint;
       //1-laka
       //2-rzeka
       //3-droga
       rodzaj:Smallint;
end;

//typ przechowywujacy obiekty takie jak auta i klody
type obiekt = record
     //wsp x prawego wierzcholka
     x:Integer;
     //liczba pixeli jaka przebywa obiekt w 1 odswiezeniu
     szybkosc:Integer;
     odstep:Integer;
     pic: AL_BITMAPptr;
end;

//typ przechowywujacy informacje o zabiach
type zaba = record
     //wsp prawego gornego wierzcholka
     x:Integer;
     y:Integer;

     hp:Integer;

     //zmienne do liczebia pkt
     pkt:Integer;
     wzg_pkt:Integer;

     //ile pixeli pozostalo do zakonczenia animacji
     ruch:Integer;

     //true jesli zaba jest na klodzie
     kloda:boolean;

     //nr odpowiadajacy nr tla na jakim znajduje sie zaba
     nr_pola:SmallInt;

     pic: AL_BITMAPptr;
end;

//wskazniki na bitmapy odpowiadajace poszczegolnym ekranom lub elemetnom ekranu
var bufor,menu,przycisk,gui,pauza,highscore,formularz: AL_BITMAPptr;

//wskazniki na dzwieki odpowiadajace odpowiednim odglosom zaby
var jump,dead: AL_SAMPLEptr;

//tablica zawierajaca informacje o podlozu
var tlo: array [1..12] of podloze;

//tablica zawierajaca informacje o obiektach (auta/klody) poruszajacych sie po planszy
var obiekty: array [1..12] of obiekt;

//zmienna przechowywujaca informacje o tym ile razy wystapilo ostatnio losowane podloze
var ostatnie: ostatnie_podloze;

//w_dol - zmienna odpowiadajaca szybkosci przewijania ekranu
//z - pomocnicza zmienna do sprawdzania na ilu klodach NIE znajduje sie zaba
//button - numer wcisnietego przycisku w menu glownym
//i - zmienna pomocnicza do petli itp.
//last_best - najgorsy wynik z TOP30
var w_dol,z,button,i,last_best: Integer;

//informacje o zabach
var zaba1,zaba2: zaba;

//zmienna wykorzystywana przez timer
var speed: LongInt;

//zmienne zawierajace informacje czy zaba jest w trakcie animacji i jestli tak to w jakim kierunku (litery odpowiadaja klawiszom)
//na dalszym etapie zmienic typ na integer i wyeksportowac do rekordu zaby
//multi - true jesli gra jest uruchomiona w trybie 2 graczy
var l,r,u,d,a,w,s,dd,multi: boolean;

//funkcja zwracajaca wskaznik do bitmapy z obrazkiem zawierajacym odpowiednia cyfre
function laduj_cyfre( cyfra:Integer): AL_BITMAPptr;
begin
     if cyfra = 0 then laduj_cyfre := al_load_bitmap('numbers/0.bmp',@al_default_palette);
     if cyfra = 1 then laduj_cyfre := al_load_bitmap('numbers/1.bmp',@al_default_palette);
     if cyfra = 2 then laduj_cyfre := al_load_bitmap('numbers/2.bmp',@al_default_palette);
     if cyfra = 3 then laduj_cyfre := al_load_bitmap('numbers/3.bmp',@al_default_palette);
     if cyfra = 4 then laduj_cyfre := al_load_bitmap('numbers/4.bmp',@al_default_palette);
     if cyfra = 5 then laduj_cyfre := al_load_bitmap('numbers/5.bmp',@al_default_palette);
     if cyfra = 6 then laduj_cyfre := al_load_bitmap('numbers/6.bmp',@al_default_palette);
     if cyfra = 7 then laduj_cyfre := al_load_bitmap('numbers/7.bmp',@al_default_palette);
     if cyfra = 8 then laduj_cyfre := al_load_bitmap('numbers/8.bmp',@al_default_palette);
     if cyfra = 9 then laduj_cyfre := al_load_bitmap('numbers/9.bmp',@al_default_palette);
end;

//procedura wyswietlajaca interfejs uzytkownika
procedure print_GUI;
var tmp: Integer;
begin
     //kolorujemy bitmape
     al_clear_to_color(gui, al_makecol(128,0,0));

     //w zaleznosci od trybu odpowiednio ladujemy interfejs
     if not multi then
     begin
         al_masked_blit( zaba1.pic,gui, 0, 0, 820, 12, zaba1.pic^.w, zaba1.pic^.h );
         tmp:=zaba1.pkt;
         al_masked_blit( laduj_cyfre(tmp div 1000),gui, 0, 0, 870, 12, 30, 40 );
         tmp := tmp - (tmp div 1000)*1000;
         al_masked_blit( laduj_cyfre(tmp div 100),gui, 0, 0, 900, 12, 30, 40 );
         tmp := tmp - (tmp div 100)*100;
         al_masked_blit( laduj_cyfre(tmp div 10),gui, 0, 0, 930, 12, 30, 40 );
         tmp := tmp - (tmp div 10)*10;
         al_masked_blit( laduj_cyfre(tmp),gui, 0, 0, 960, 12, 30, 40 );
         al_masked_blit( al_load_bitmap('buttons/tytul.bmp',@al_default_palette),gui, 0, 0, 190, 0, 240, 65 );
     end
     else al_masked_blit( al_load_bitmap('buttons/tytul.bmp',@al_default_palette),gui, 0, 0, 380, 0, 240, 65 );
end;

//procedura rysujaca ekran z TOP30 najlepszych wynikow
procedure print_highscore;
//zmienne w ktorych zapisujemy odczytane z pliku dane
var kto,wynik,out:String;
var i:Integer;
//klik - na ilu przyciskach NIE znajduje sie myszka
//tmp_button - tymczasowo przechowywana wartosc wcisnietego przysisku
var klik,tmp_button: Integer;
//pressed - jesli myszka juz na przycisku to false, jesli dopiero najechano to true
var pressed : boolean;
//plik z najlepszymi wynikami
var plik :text;
begin
       //ustawiamy domyslne wartosci zmiennym wewnetrznym funkcji
       pressed:=false;
       tmp_button:=0;

     //kolorujemy bitmape
     al_clear_to_color(highscore,al_makecol(128,0,0));
     al_masked_blit( al_load_bitmap('buttons/best.bmp',@al_default_palette),highscore, 0, 0, 200, 12, 600, 200 );

     //otwieramy plik w trybie odczytu
     assign(plik,'data/highscore.txt');
     reset(plik);

     //rysujemy pierwszy wiersz tabeli
     al_rectfill(highscore,200,166,800,178,al_makecol(64,0,64));
     al_textout_ex( highscore, al_font, 'NR', 200, 168, al_makecol( 0, 100, 243 ), - 1 );
     al_textout_ex( highscore, al_font, 'DATA', 230, 168, al_makecol( 0, 100, 243 ), - 1 );
     al_textout_ex( highscore, al_font, 'WYNIK', 736, 168, al_makecol( 0, 100, 243 ), - 1 );

     //czytamy z pliku dane i wyswietlamy je w naszej 'tabeli'
     for i:=1 to 30 do
     begin
          if i mod 2 = 0 then al_rectfill(highscore,200,178+(i-1)*12,800,190+(i-1)*12,al_makecol(64,0,64))
          else al_rectfill(highscore,200,178+(i-1)*12,800,190+(i-1)*12,al_makecol(128,0,64));

          Str(i,out);
          readln(plik,wynik);
          readln(plik,kto);
          al_textout_ex( highscore, al_font, out, 200, 180+(i-1)*12, al_makecol( 0, 100, 243 ), - 1 );
          al_textout_ex( highscore, al_font, kto, 230, 180+(i-1)*12, al_makecol( 0, 100, 243 ), - 1 );
          al_textout_ex( highscore, al_font, wynik, 736, 180+(i-1)*12, al_makecol( 0, 100, 243 ), - 1 );
     end;

     //wyswietlamy przycisk menu
     przycisk:=al_load_bitmap('buttons/menu.bmp',@al_default_palette);
     al_masked_blit( przycisk,highscore, 0, 0, 380, 550, przycisk^.w, przycisk^.h );

     //kopiujemy bufor na ekran
     al_blit( highscore, al_screen, 0, 0, 0, 0, highscore^.w, highscore^.h );

     //petla sprawdzajaca czy gracz wcisnal/najechal na przycisk menu
     repeat
     begin
       //petla sprawdzajaca czy i jaki przycisk zostal wcisniety
       if (al_mouse_y < 630) and (al_mouse_y>550) and (al_mouse_b = 1) and (al_mouse_x>380) and (al_mouse_x<620) then
       begin
            tmp_button:=1;
            al_play_sample( al_load_sample( 'sounds/click_on.wav' ), 255, 127, 1000, false );
       end;

       klik:=0;

       //petla podswietlajaca i odtwarzajaca odpowiedni dzwiek po najechaniu myszka
       if (al_mouse_y < 630) and (al_mouse_y>550) and (al_mouse_x>380) and (al_mouse_x<620) then
       begin
           if pressed then
           begin
               al_play_sample( al_load_sample( 'sounds/click_on.wav' ), 255, 127, 1000, false );
               pressed:=false;
           end;
           przycisk:=al_load_bitmap('buttons/pressed.bmp',@al_default_palette);
           al_masked_blit( przycisk,highscore, 0, 0, 380, 550, przycisk^.w, przycisk^.h );
           al_blit( highscore, al_screen, 0, 0, 0, 0, menu^.w, menu^.h );
       end
       else
       begin
           Inc(klik);
           przycisk:=al_load_bitmap('buttons/unpressed.bmp',@al_default_palette);
           al_masked_blit( przycisk,highscore, 0, 0, 380, 550, przycisk^.w, przycisk^.h );
           al_blit( highscore, al_screen, 0, 0, 0, 0, menu^.w, menu^.h );
       end;

       //jesli myszka teraz nie jest na zadnym klawiszu to w nastepnej petli mozna odtworzyc dzwiek najechania na przycisk
       //jesli myszka jest na przycisku to w nastepnej petli nie odtwarzaj dzwieku
       if klik = 1 then pressed:=true;
    end;
    until tmp_button <> 0;

    //zamykamy otwarty plik
    close(plik);
end;

//procedura informujaca o osiagnieciu wyniku z TOP30
procedure print_formularz;
begin
     al_clear_to_color(formularz,al_makecol(128,0,0));
     al_masked_blit( al_load_bitmap('buttons/gratki.bmp',@al_default_palette),formularz, 0, 0,30, 32, 240, 80);
     al_textout_ex( formularz, al_font, 'Twoj wynik to TOP30!', 60 , 112, al_makecol( 0, 100, 243 ), - 1 );
     al_blit( formularz, al_screen, 0, 0, 350, 225, formularz^.w, formularz^.h );
     delay(1000);
end;

//procedura dodajaca wynik do TOP30
procedure zmien_highscore(ile:Integer);
//tablice do ktorych wczytamy dane z pliku przed ich wyczyszczeniem
var nick: array [1..30] of String;
var pkt: array [1..30] of Integer;
//plik z ktorego bedziemy czytac i do ktorego bedziemy zapisywac
var tmp_read:text;
//tymczasowe zmienne do podmiany wynikow
var pkt_tmp: Integer;
var nick_tmp: String;

var i,j:Integer;

//true jesli nowy wynik wpisano juz do talicy
var wpisano: boolean;

// zmienne do zapisu i konwersji daty
var y, m, d, dw,h, min, s, s100 : Word;
var y1, m1, d1, h1, min1, s1: String;
begin

     //informujemy gracza o dostaniu sie do TOP30
     print_formularz;

     //odczytujemy aktualna date i zapisujemy ja do tymczasowej zmiennej
     GetDate(y, m, d, dw);
     GetTime(h,min,s,s100);
     Str(d,d1);
     Str(m,m1);
     Str(y,y1);
     Str(h,h1);
     Str(min,min1);
     Str(s,s1);
     nick_tmp:=d1+'.'+m1+'.'+y1+'   '+h1+':'+min1+':'+s1;

     //otwieramy plik w trybie do odczytu
     assign(tmp_read,'data/highscore.txt');
     reset(tmp_read);

     wpisano:=false;
     j:=0;

     //tworzymy tablice najlepszych wynikow i wstawimy do niej nowy element
     for i:=1 to 30 do
     begin
          if j<>i then
          begin
               readln(tmp_read,pkt[i]);
               if (pkt[i] < ile) and (not wpisano) then
               begin
                    pkt[i]:=pkt_tmp;
                    pkt[i]:=ile;
                    nick[i]:=nick_tmp;
                    pkt[i+1]:=pkt_tmp;
                    readln(tmp_read,nick[i+1]);
                    j:=i;
                    wpisano:=true;
               end
               else readln(tmp_read,nick[i]);
          end;
     end;

     //zamykamy plik
     close(tmp_read);

     //otwieramy plik w trybie nadpisywania
     assign(tmp_read,'data/highscore.txt');
     rewrite(tmp_read);

     //zapisujemy tabele do pliku
     for i:=1 to 30 do
     begin
          Writeln(tmp_read,pkt[i]);
          Writeln(tmp_read,nick[i]);
     end;

     //zamykamy plik
     close(tmp_read);

end;

//funkcja wyswietlajaca menu pauzy
//zwraca numer przycisku jaki zostal wcisniety
function print_pauza(koniec:boolean):Integer;
//klik - na ilu przyciskach NIE znajduje sie myszka
//tmp_button - tymczasowo przechowywana wartosc wcisnietego przysisku
//tmp - tymczasowa zmienna do wyliczania punktow gracza
var klik,tmp_button,tmp: Integer;
//pressed - jesli myszka juz na przycisku to false, jesli dopiero najechano to true
var pressed : boolean;
begin
     //ustawiamy domyslne wartosci zmiennym wewnetrznym funkcji
     pressed:=false;
     tmp_button:=0;
     pressed:=true;

     //jesli zakonczono gre i osiagnieto TOP30 to wyswietl formularz
     if (not multi) and (koniec) and (zaba1.pkt > last_best) then zmien_highscore(zaba1.pkt);

     //kolorujemy tlo
     al_clear_to_color(pauza, al_makecol(128,0,0));

     //w zaleznosci od trybu gry i atrybutu wywolania pauzy odpowiednio ladujemy statyczne elementy menu
     if (not multi) then
            begin
                  al_masked_blit( al_load_bitmap('graphic/zaba2.bmp',@al_default_palette),pauza, 0, 0, 65, 42, zaba1.pic^.w, zaba1.pic^.h );
                  tmp:=zaba1.pkt;
                  al_masked_blit( laduj_cyfre(tmp div 1000),pauza, 0, 0, 115, 42, 30, 40 );
                  tmp := tmp - (tmp div 1000)*1000;
                  al_masked_blit( laduj_cyfre(tmp div 100),pauza, 0, 0, 145, 42, 30, 40 );
                  tmp := tmp - (tmp div 100)*100;
                  al_masked_blit( laduj_cyfre(tmp div 10),pauza, 0, 0, 175, 42, 30, 40 );
                  tmp := tmp - (tmp div 10)*10;
                  al_masked_blit( laduj_cyfre(tmp),pauza, 0, 0, 205, 42, 30, 40 );
            end
            else
            begin
                 if koniec then
                 begin
                      al_masked_blit( al_load_bitmap('buttons/wygrywa.bmp',@al_default_palette),pauza, 0, 0,10, 32, 240, 80);
                      if zaba1.hp > zaba2.hp then al_masked_blit( al_load_bitmap('graphic/zaba2.bmp',@al_default_palette),pauza, 0, 0, 250, 52, zaba1.pic^.w, zaba1.pic^.h )
                      else al_masked_blit( al_load_bitmap('graphic/zaba1.bmp',@al_default_palette),pauza, 0, 0, 250, 52, zaba1.pic^.w, zaba1.pic^.h )
                 end
                 else al_masked_blit( al_load_bitmap('buttons/pauza.bmp',@al_default_palette),pauza, 0, 0,30, 32, 240, 80);
            end;

     //w zaleznosci od trybu gry i atrybutu wywolania pauzy odpowiednio ladujemy dynamiczne elementy menu
     if not koniec then
     begin
          przycisk:=al_load_bitmap('buttons/wznow.bmp',@al_default_palette);
          al_masked_blit( przycisk,pauza, 0, 0, 30, 125, przycisk^.w, przycisk^.h );
     end
     else
     begin
          przycisk:=al_load_bitmap('buttons/zagraj_ponownie.bmp',@al_default_palette);
          al_masked_blit( przycisk,pauza, 0, 0, 30, 125, przycisk^.w, przycisk^.h );
     end;

     przycisk:=al_load_bitmap('buttons/menu.bmp',@al_default_palette);
     al_masked_blit( przycisk,pauza, 0, 0, 30, 210, przycisk^.w, przycisk^.h );


     //petla zapetlajaca sie az gracz wybierze jeden z przyciskow
     repeat
     begin
          //petla sprawdzajaca czy i jaki przycisk zostal wcisniety
          for i:=1 to 2 do
          if (al_mouse_y < 380+(i-1)*85) and (al_mouse_y>300+(i-1)*85) and (al_mouse_b = 1) and (al_mouse_x>380) and (al_mouse_x<620) then
          begin
               tmp_button:=i;
               al_play_sample( al_load_sample( 'sounds/click_on.wav' ), 255, 127, 1000, false );
          end;
          klik:=0;

          //petla podswietlajaca i odtwarzajaca odpowiedni dzwiek po najechaniu myszka
          for i:=1 to 2 do
          if (al_mouse_y < 380+(i-1)*85) and (al_mouse_y>300+(i-1)*85) and (al_mouse_x>380) and (al_mouse_x<620) then
          begin
               if pressed then
               begin
                    al_play_sample( al_load_sample( 'sounds/click_on.wav' ), 255, 127, 1000, false );
                    pressed:=false;
               end;
               przycisk:=al_load_bitmap('buttons/pressed.bmp',@al_default_palette);
               al_masked_blit( przycisk,pauza, 0, 0, 30, 125+(i-1)*85, przycisk^.w, przycisk^.h );
               al_blit( pauza, bufor, 0, 0, 350, 175, pauza^.w, pauza^.h );
          end
          else
          begin
               Inc(klik);
               przycisk:=al_load_bitmap('buttons/unpressed.bmp',@al_default_palette);
               al_masked_blit( przycisk,pauza, 0, 0, 30, 125+(i-1)*85, przycisk^.w, przycisk^.h );
               al_blit( pauza, bufor, 0, 0, 350, 175, pauza^.w, pauza^.h );
          end;

          //jesli myszka teraz nie jest na zadnym klawiszu to w nastepnej petli mozna odtworzyc dzwiek najechania na przycisk
          //jesli myszka jest na przycisku to w nastepnej petli nie odtwarzaj dzwieku
          if klik = 2 then pressed:=true;
          al_blit( bufor, al_screen, 0, 0, 0, 0, bufor^.w, bufor^.h );
          print_pauza:=tmp_button;
          if (tmp_button = 1) and ( not koniec) then print_pauza:=3;
     end;
     until tmp_button <> 0;
end;

//funkcja niezbedna do dzialania timera
procedure timer; CDECL;
begin
     inc(speed);
end;

//procedura ladujaca wszystkie procedury niezbedne do dzialania allegro
procedure inicjalizacja;
begin
     al_init;
     al_install_keyboard;
     al_set_color_depth(32);
     al_set_gfx_mode(Al_GFX_AUTODETECT_WINDOWED,ScreenWidth,ScreenHeight,0,0);
     al_install_timer;
     al_install_int_ex(@timer,al_bps_to_timer(30));
     al_install_sound(AL_DIGI_AUTODETECT, AL_MIDI_AUTODETECT);
     al_set_volume( 255, 255 );
     al_set_window_title('Frogger by motek');
     al_set_palette(al_default_palette);
     al_install_mouse();
     al_show_mouse( al_screen );
     al_unscare_mouse();
end;

//procedura losujaca szybkosc z jaka beda sie poruszac obiekty oraz
procedure losuj_obiekt(indeks:Integer);
var x:Integer;
begin
     //dla trawy nie losuj obiektow
     if tlo[indeks].typ = 1 then Write()
     //dla rzeki losuj wg. regul
     else if tlo[indeks].typ = 2 then
     begin
          randomize;
          obiekty[indeks].x:=random(500);
          randomize;
          obiekty[indeks].szybkosc:=random(6)+1;
          if (tlo[indeks].typ <> tlo[indeks-1].typ) and (indeks<>1) then
          begin
               repeat obiekty[indeks].szybkosc:=random(9)+1;
               until (obiekty[indeks].szybkosc > obiekty[indeks-1].szybkosc+2) or (obiekty[indeks].szybkosc < obiekty[indeks-1].szybkosc-2) ;
          end;
          randomize;
          obiekty[indeks].odstep:=random(300)+300;
          obiekty[indeks].pic:=al_load_bitmap('graphic/kloda.bmp',@al_default_palette);
     end
     //dla drogi losuj wg. regul
     else
     begin
          randomize;
          obiekty[indeks].x:=random(1000);
          randomize;
          obiekty[indeks].szybkosc:=random(6)+1;
          randomize;
          if (tlo[indeks].typ <> tlo[indeks-1].typ) and (indeks<>1) then
          begin
               repeat obiekty[indeks].szybkosc:=random(9)+1;
               until (obiekty[indeks].szybkosc > obiekty[indeks-1].szybkosc+2) or (obiekty[indeks].szybkosc < obiekty[indeks-1].szybkosc-2) ;
          end;
          obiekty[indeks].odstep:=random(300)+300;
          //losuj jedna z 3 grafik przewidzianych dla auta
          randomize;
          x:=random(3);
          if x = 0 then obiekty[indeks].pic:=al_load_bitmap('graphic/auto.bmp',@al_default_palette)
          else if x = 1 then obiekty[indeks].pic:=al_load_bitmap('graphic/auto1.bmp',@al_default_palette)
          else if x = 2 then obiekty[indeks].pic:=al_load_bitmap('graphic/auto2.bmp',@al_default_palette);
     end;
end;

//procedura losujaca pole wg. ustalonych wytycznych
procedure losuj_pole(var pole:podloze);
//laka-procentowe prawdopodobienstwo wylosowania laki
//rzeka-             ---||---                    rzeki
//rand-losowa liczba
//tmp-tymczasowa zmienna w ktorej zapisana jest informacja o typie pola sprzed losowania
var laka,rzeka,rand,tmp:Integer;
begin
     //jesli poprzednie pole to laka
     if ostatnie.rodzaj = 1 then
     begin
          if ostatnie.ile = 1 then
          begin
               laka:=10;
               rzeka:=20;
          end
          else
          begin
               laka:=0;
               rzeka:=40;
          end;
     end;

     //jesli poprzednie pole to rzeka
     if ostatnie.rodzaj = 2 then
     begin
          if ostatnie.ile = 1 then
          begin
               laka:=30;
               rzeka:=50;
          end
          else if ostatnie.ile = 2 then
          begin
               laka:=50;
               rzeka:=20;
          end
          else
          begin
               laka:=90;
               rzeka:=0;
          end;
     end;

     //jesli poprzednie pole to droga
     if ostatnie.rodzaj = 3 then
     begin
          if ostatnie.ile = 1 then
          begin
               laka:=10;
               rzeka:=10;
          end
          else if ostatnie.ile = 2 then
          begin
               laka:=10;
               rzeka:=20;
          end
          else if ostatnie.ile = 3 then
          begin
               laka:=40;
               rzeka:=20;
          end
          else
          begin
               laka:=90;
               rzeka:=10;
          end;
     end;

     //zapisujemy obecny rodzaj pola
     tmp:=ostatnie.rodzaj;
     //losujemy liczbe
     randomize;
     rand:=random(99)+1;

     //w zaleznosci w jakim zakresie wylosowala sie liczba przypisz odpowiednie pole
     if rand<=laka then
     begin
          ostatnie.rodzaj:=1;
          pole.dang:=false;
          pole.pic:=al_load_bitmap('graphic/laka.bmp',@al_default_palette);
          pole.typ:=1;
     end
     else if (rand>laka) and (rand<=rzeka+laka) then
     begin
          ostatnie.rodzaj:=2;
          pole.dang:=true;
          pole.pic:=al_load_bitmap('graphic/rzeka.bmp',@al_default_palette);
          pole.typ:=2;
     end
     else
     begin
          ostatnie.rodzaj:=3;
          pole.dang:=false;
          pole.pic:=al_load_bitmap('graphic/droga.bmp',@al_default_palette);
          pole.typ:=3;
     end;

     if ostatnie.rodzaj = tmp then inc(ostatnie.ile)
     else ostatnie.ile:=1;

end;

//tworzy poczatkowa postac planszy
procedure utworz_plansze;
var i,j:integer;
//tymczasowy plik dzieki ktoremy mozemy odczytac najgorszy wynik z TOP30
var tmp_read:text;
//tymczasowa zmienn do przewiniecia wskaznika w pliku
var tmp:String;
begin

     //otwieramy plik w trybie do odczyty
     assign(tmp_read,'data/highscore.txt');
     reset(tmp_read);

     //przewijamy na koniec pliku
     for i:=1 to 29 do
     begin
          Readln(tmp_read,tmp);
          Readln(tmp_read,tmp);
     end;

     //zaisujemy najgorszy wynik z TOP30
     Readln(tmp_read,last_best);

     //zamykamy plik
     close(tmp_read);

     //ustawiamy domyslna szybkosc przewijania planszy
     w_dol:=1;
     jump := al_load_sample( 'sounds/jump.wav' );

     //pierwsze 2 pola to zawsze laki
     tlo[1].x:=0;
     tlo[1].y:=ScreenHeight-2*skok;
     tlo[1].dang:=false;
     tlo[1].pic:=al_load_bitmap('graphic/laka.bmp',@al_default_palette);
     tlo[1].typ:=1;
     al_masked_blit( tlo[1].pic,bufor, 0, 0, 0, tlo[1].y, tlo[1].pic^.w, tlo[1].pic^.h );
     losuj_obiekt(1);
     tlo[2].x:=0;
     tlo[2].y:=ScreenHeight-3*skok;
     tlo[2].dang:=false;
     tlo[2].pic:=al_load_bitmap('graphic/laka.bmp',@al_default_palette);
     tlo[2].typ:=1;
     al_masked_blit( tlo[2].pic,bufor, 0, 0, tlo[2].x, tlo[2].y, tlo[2].pic^.w, tlo[2].pic^.h );
     losuj_obiekt(2);
     ostatnie.ile:=2;
     ostatnie.rodzaj:=1;

     //losuj pozostale 8 pol planszy
     for i:=3 to 12 do
     begin
          tlo[i].x:=0;
          tlo[i].y:=ScreenHeight-(i+1)*skok;
          losuj_pole(tlo[i]);
          losuj_obiekt(i);
          al_masked_blit( tlo[i].pic,bufor, 0, 0, tlo[i].x, tlo[i].y, tlo[i].pic^.w, tlo[i].pic^.h );
          for j:=1 to 5 do
          begin
              if tlo[i].typ <> 1 then al_masked_blit(obiekty[i].pic,bufor, 0, 0,obiekty[i].x+(j-1)*obiekty[i].odstep, tlo[i].y+3, obiekty[i].pic^.w, obiekty[i].pic^.h );
          end;
     end;
     //wcytaj zabe i przypisz jej domyslne polozenie w zaleznoscu od wybranego trybu gry
	 if multi then 
	 begin
		 zaba2.x:=ScreenWidth div 4 - 20;
		 zaba2.y:=tlo[2].y+12;
		 zaba2.nr_pola:=2;
                 zaba2.hp := 1;
		 zaba2.ruch:=0;
		 zaba2.pic:=al_load_bitmap('graphic/zaba1.bmp',@al_default_palette);
                 zaba2.pkt:=0;
                 zaba2.wzg_pkt:=0;
		 al_masked_blit( zaba2.pic,bufor, 0, 0, zaba2.x, tlo[1].y, zaba2.pic^.w, zaba2.pic^.h );
		 
		 zaba1.x:=3*(ScreenWidth div 4) - 20;
		 zaba1.y:=tlo[2].y+12;
		 zaba1.nr_pola:=2;
                 zaba1.hp := 1;
		 zaba1.ruch:=0;
                 zaba1.pkt:=0;
                 zaba1.wzg_pkt:=0;
		 zaba1.pic:=al_load_bitmap('graphic/zaba2.bmp',@al_default_palette);
		 al_masked_blit( zaba1.pic,bufor, 0, 0, zaba2.x, tlo[1].y, zaba2.pic^.w, zaba2.pic^.h );
	 end
	 else
	 begin
		 zaba1.x:=ScreenWidth div 2 - 25;
		 zaba1.y:=tlo[2].y+12;
		 zaba1.nr_pola:=2;
                 zaba1.hp := 1;
		 zaba1.ruch:=0;
                 zaba1.pkt:=0;
                 zaba1.wzg_pkt:=0;
		 zaba1.pic:=al_load_bitmap('graphic/zaba2.bmp',@al_default_palette);
                 zaba2.pic:=al_load_bitmap('graphic/zaba1.bmp',@al_default_palette);
		 al_masked_blit( zaba1.pic,bufor, 0, 0, zaba1.x, tlo[1].y, zaba1.pic^.w, zaba1.pic^.h );
	end;
end;

//przewijajaca ekran w dol razem ze znajdujacymi sie na nim obiektami
procedure przewin;
var i,j:Integer;
begin
     //wyczysc bufor;
     al_clear_to_color(bufor, al_makecol(10,10,10));
     //przesun tlo
     if zaba1.y < 207 then w_dol := 8 ;
     if (zaba2.y < 207) and (multi) then w_dol := 8 ;
     for i:=1 to 12 do
     begin
          //przewin wszystkie fragmenty tla na ekranie
          tlo[i].y:=tlo[i].y+w_dol;
          al_masked_blit( tlo[i].pic,bufor, 0, 0, tlo[i].x, tlo[i].y, tlo[i].pic^.w, tlo[i].pic^.h );
     end;

     //jesli zaba jest martwa to nalezy ja teraz wyswietlic i nie przesuwac
     if zaba1.hp = 0 then al_masked_blit( zaba1.pic,bufor, 0, 0, zaba1.x, zaba1.y, zaba1.pic^.w, zaba1.pic^.h );
     if (zaba2.hp = 0) and (multi) then al_masked_blit( zaba2.pic,bufor, 0, 0, zaba2.x, zaba2.y, zaba2.pic^.w, zaba2.pic^.h );

     //przesun obiekty w prawo zgodnie z ich szybkoscia
     for i:=1 to 12 do
     begin
          obiekty[i].x:=obiekty[i].x-obiekty[i].szybkosc;
          for j:=1 to 5 do
          begin
              if tlo[i].typ <> 1 then
              al_masked_blit(obiekty[i].pic,bufor, 0, 0,obiekty[i].x+(j-1)*obiekty[i].odstep, tlo[i].y+3, obiekty[i].pic^.w, obiekty[i].pic^.h );
          end;
          if obiekty[i].x<-1*250 then obiekty[i].x:=obiekty[i].x+obiekty[i].odstep;
     end;

     //przesun zabe1 w dol
     zaba1.y:=zaba1.y+w_dol;

     //jesli zaba zajduje sie w trakcie animacji to przewin ja o odpowiednia liczbe pixeli
     if zaba1.ruch > 2 then zaba1.ruch:=zaba1.ruch-8
     else
     begin
          zaba1.ruch:=0;
          if l then zaba1.x:=zaba1.x-1
          else if r then zaba1.x:=zaba1.x+1
          else if u then zaba1.y:=zaba1.y-1
          else if d then zaba1.y:=zaba1.y+1;
          l:=false;
          r:=false;
          u:=false;
          d:=false;
     end;

     if l then zaba1.x:=zaba1.x-8
     else if r then zaba1.x:=zaba1.x+8
     else if u then zaba1.y:=zaba1.y-8
     else if d then zaba1.y:=zaba1.y+8;

     //przypisz zabie nr_pola na jakim sie znajduje
     for i:=1 to 12 do
          if (zaba1.y < tlo[i].y - 65) and (zaba1.y > tlo[i].y) then zaba1.nr_pola:=i;


     //jesli zaba jest na klodzie to nalezy ja odpowiednio przesunac o predkosc klody
     if zaba1.kloda then zaba1.x:=zaba1.x-obiekty[zaba1.nr_pola].szybkosc;
     if zaba1.hp = 1 then al_masked_blit( zaba1.pic,bufor, 0, 0, zaba1.x, zaba1.y, zaba1.pic^.w, zaba1.pic^.h );

     //jesli zaba wyszla za ekran z lewej lub prawej to cofnij ja na brzeg ekranu
     if zaba1.x < 0 then zaba1.x:=0;
     if zaba1.x > 950 then zaba1.x:=950;

     //wykonaj analogiczne czynnosci dla zaby2 jesli uruchomiono tryb 2 graczy
	 if multi then
	 begin
		 zaba2.y:=zaba2.y+w_dol;

		 if zaba2.ruch > 2 then zaba2.ruch:=zaba2.ruch-8
		 else
		 begin
			  zaba2.ruch:=0;
			  if a then zaba2.x:=zaba2.x-1
			  else if dd then zaba2.x:=zaba2.x+1
			  else if w then zaba2.y:=zaba2.y-1
			  else if s then zaba2.y:=zaba2.y+1;
			  a:=false;
			  dd:=false;
			  w:=false;
			  s:=false;
		 end;

		 if a then zaba2.x:=zaba2.x-8
		 else if dd then zaba2.x:=zaba2.x+8
		 else if w then zaba2.y:=zaba2.y-8
		 else if s then zaba2.y:=zaba2.y+8;

		 for i:=1 to 12 do
			  if (zaba2.y < tlo[i].y - 65) and (zaba2.y > tlo[i].y) then zaba2.nr_pola:=i;


		  if z = 1 then zaba2.x:=zaba2.x-obiekty[zaba2.nr_pola].szybkosc;


		 //jesli zaba wyszla za ekran to cofnij ja na brzeg ekranu
		 if zaba2.x < 0 then zaba2.x:=0;
		 if zaba2.x > 950 then zaba2.x:=950;

                 if zaba2.kloda then zaba2.x:=zaba2.x-obiekty[zaba2.nr_pola].szybkosc;

                 if zaba2.hp = 1 then al_masked_blit( zaba2.pic,bufor, 0, 0, zaba2.x, zaba2.y, zaba2.pic^.w, zaba2.pic^.h );
         end;

     //jesli tlo jest pod ekranem to przeloz je na gore i wylosuj jego typ
     for i:=1 to 12 do
     begin
     if tlo[i].y>=10*skok then
     begin
          losuj_pole(tlo[i]);
          losuj_obiekt(i);
          if i <> 1 then tlo[i].y:=tlo[i-1].y-65
          else tlo[i].y:=tlo[12].y-65;
     end;
     end;
     w_dol := 1;
end;

//sprawdza czy gracz zginal
function skucha(var zaba :zaba):boolean;
var i,j,k:Integer;
begin
     //ustawiamy domyslne wartosci zmiennych
     zaba.kloda:=false;
     k:=0;
     skucha:=false;

     //jesli plansza uciekla spod gracza to porazka
     if zaba.y>550 then
     begin
          skucha:=true;
          zaba.hp:=0;
     end
     //jesli nie to sprawdz pozostale warunki
     else
     begin

     for i:=1 to 12 do
     begin
          //jesli zaba znajduje sie na odpowiednim polu
          if ((zaba.y > tlo[i].y) and (zaba.y < tlo[i].y + 65)) or
             ((zaba.y +40 > tlo[i].y) and (zaba.y + 40 < tlo[i].y + 65)) then
          begin
               for j:=1 to 5 do
               begin
                    //i znajduje sie na obiekcie
                    if (zaba.x+40>obiekty[i].x+(j-1)*obiekty[i].odstep) and
                       (zaba.x<obiekty[i].x+(j-1)*obiekty[i].odstep+120) then
                    begin
                         //ktorym jest kloda
                         if tlo[i].typ = 2 then
                         begin
                              zaba.kloda := true;
                              zaba.nr_pola:=i;
                              break;
                         end
                         //ktorym jest auto
                         else if tlo[i].typ = 3 then
                         begin
                              skucha:=true;
                              if zaba.hp = 1 then
                              begin
                                   dead := al_load_sample( 'sounds/dead_car.wav' );
                                   al_play_sample( dead, 255, 127, 1000, false );
                                   zaba.pic := al_load_bitmap('graphic/plama.bmp',@al_default_palette);
                                   zaba.hp:=0;
                              end;
                              break;
                         end;
                    end
                    //i nie znajduje sie na obiekcie
                    else
                    begin
                         //i jest w wodzie
                         if tlo[i].typ = 2 then
                         begin
                              Inc(k);
                         end;
                    end;
               end;
               if k = 5 then
               begin
                    skucha:=true;
                    if zaba.hp = 1 then
                    begin
                          dead := al_load_sample( 'sounds/dead_water.wav' );
                          zaba.pic := al_load_bitmap('graphic/zaba0.bmp',@al_default_palette);
                          al_play_sample( dead, 255, 127, 1000, false );
                          zaba.hp:=0;
                    end;
               end;
          end;
     end;
     end;

end;

//wczytuje klawisze od gracza i odpowiednio steruje zaba
procedure ruch;
begin
     if zaba1.ruch=0 then
     begin
     zaba1.ruch:=65;
     if al_key[ AL_KEY_LEFT ] then
     begin
          l:=true;
          al_play_sample( jump, 255, 127, 1000, false );
     end
     else if al_key[ AL_KEY_RIGHT ] then
     begin
          r:=true;
          al_play_sample( jump, 255, 127, 1000, false );
     end
     else if al_key[ AL_KEY_UP ] then
     begin
          u:=true;
          if zaba1.wzg_pkt = zaba1.pkt then Inc(zaba1.pkt);
          al_play_sample( jump, 255, 127, 1000, false );
          Inc(zaba1.wzg_pkt);
     end
     else if al_key[ AL_KEY_DOWN ] then
     begin
          d:=true;
          al_play_sample( jump, 255, 127, 1000, false );
          Dec(zaba1.wzg_pkt);
     end
     else zaba1.ruch:=0;
     end;
	 
	 if multi then 
	 begin
		if zaba2.ruch=0 then
		begin
		zaba2.ruch:=65;
		if al_key[ AL_KEY_A ] then
		begin
			a:=true;
			al_play_sample( jump, 255, 127, 1000, false );
		end
		else if al_key[ AL_KEY_D ] then
		begin
			dd:=true;
			al_play_sample( jump, 255, 127, 1000, false );
		end
		else if al_key[ AL_KEY_W ] then
		begin
			w:=true;
			if zaba2.wzg_pkt = zaba2.pkt then Inc(zaba2.pkt);
			al_play_sample( jump, 255, 127, 1000, false );
			Inc(zaba2.wzg_pkt);
                end
                else if al_key[ AL_KEY_S ] then
                begin
			s:=true;
			al_play_sample( jump, 255, 127, 1000, false );
			Dec(zaba2.wzg_pkt);
                end
                else zaba2.ruch:=0;
                end;
	 end;
end;

//procedura odpowiadajaca za dzialanie gry
//procedura ustawia odpowiednio przekazany menus_button w zaleznosci od tego co chce zrobic gracz po przerwaniu gry
procedure gra(var menus_button:Integer);
//skucie - zawiera informacje ilu graczy sie skulo
//pauza_button - przechowuje numer przycisku wybranego w pauzie
var skucie,pauza_button,tmp_timer:Integer;
//koniec - czy nalezy przerwac wykonywanie dzialania funkcji
var koniec:boolean;
begin
  //ustawiamy domyslne wartosci zmiennych wewnetrznych funkcji
  pauza_button:=0;
  skucie:=0;
  koniec:=false;

  //rysujemy poczatkowa plansze i kopiujemy ja na ekran
  utworz_plansze;
  al_blit( bufor, al_screen, 0, 0, 0, 0, bufor^.w, bufor^.h );

  //ustawimy timer na 0
  speed:=0;
  //glowna petla gry
  repeat
  while speed > 0 do
  begin
       //rysujemy interfejs uzytkownika
       print_GUI;
       al_blit( gui, al_screen, 0, 0, 0, 585, gui^.w, gui^.h );

       //w zaleznosci od trybu gry sprawdzamy warunki skuchy
       if not multi then
       begin
            if (not skucha(zaba1)) and (skucie = 0) then ruch
            else Inc(skucie);
       end
	   else
       begin
	   if (not skucha(zaba1)) and (not skucha(zaba2)) and (skucie = 0) then ruch
           else Inc(skucie);
       end;

       //przewijamy plansze w dol
       przewin;

       //jesli nastapilo skucie lub jesli nacisnieto ESC wyswietlamy menu pauzy
       tmp_timer:=speed;
       if (skucie <> 0) then pauza_button:=print_pauza(true);
       if (al_key[AL_KEY_ESC]) then pauza_button:=print_pauza(false);
       speed:=tmp_timer;

       //jesli w pauzie wybrano przycisk zagrania ponownie to w glownej petli gry
       //ustawiamy przycisk odpowiadajacy ponownemu wywolaniu gry w tym samym trybie
       if pauza_button = 1 then
       begin
            if multi then menus_button:=6
            else menus_button:=5;
            koniec:=true;
            break;
       end;
       if pauza_button = 2 then
       begin
            koniec:=true;
            break;
       end;


       //kopiujemy bufor z plansza na ekran
       al_blit( bufor, al_screen, 0, 0, 0, 0, bufor^.w, bufor^.h );

       //dekrementujemy timer
       dec(speed);
  end;
  until (koniec) ;
end;

//funkcja rysujaca menu i zwracajaca numer wcisnietego przycisku
function menus:Integer;
//klik - na ilu przyciskach NIE znajduje sie myszka
//tmp_button - tymczasowo przechowywana wartosc wcisnietego przysisku
var klik,tmp_button: Integer;
//pressed - jesli myszka juz na przycisku to false, jesli dopiero najechano to true
var pressed : boolean;
begin
  //ustawiamy domyslne wartosci zmiennym wewnetrznym funkcji
  menus:=0;
  pressed:=false;
  tmp_button:=0;

  //tworzymy bitmape menu i kolorujemy ja
  menu:= al_create_bitmap(1000,650);
  al_clear_to_color(bufor, al_makecol(10,10,10));
  al_clear_to_color(menu, al_makecol(126,152,80));
  al_rectfill(menu,250,0,750,650,al_makecol(128,0,0));

  //rysujemy logo oraz przyciski
  al_circlefill(menu,500,100,80,al_makecol(250,244,19));
  przycisk:=al_load_bitmap('graphic/zaba2.bmp',@al_default_palette);
  al_masked_blit( przycisk,menu, 0, 0, 480, 80, przycisk^.w, przycisk^.h );
  przycisk:=al_load_bitmap('buttons/tytul.bmp',@al_default_palette);
  al_masked_blit( przycisk,menu, 0, 0, 380, 125, przycisk^.w, przycisk^.h );
  przycisk:=al_load_bitmap('buttons/1_gracz.bmp',@al_default_palette);
  al_masked_blit( przycisk,menu, 0, 0, 380, 200, przycisk^.w, przycisk^.h );
  przycisk:=al_load_bitmap('buttons/2_graczy.bmp',@al_default_palette);
  al_masked_blit( przycisk,menu, 0, 0, 380, 300, przycisk^.w, przycisk^.h );
  przycisk:=al_load_bitmap('buttons/NW.bmp',@al_default_palette);
  al_masked_blit( przycisk,menu, 0, 0, 380, 400, przycisk^.w, przycisk^.h );
  przycisk:=al_load_bitmap('buttons/koniec.bmp',@al_default_palette);
  al_masked_blit( przycisk,menu, 0, 0, 380, 500, przycisk^.w, przycisk^.h );
  przycisk:=al_load_bitmap('buttons/pressed.bmp',@al_default_palette);

  //blokujemy mozliwosc przypadkowego wcisniecia przycisku
  delay(200);

  //petla zapetlajaca sie az gracz wybierze jeden z przyciskow
  repeat
  begin
       //petla sprawdzajaca czy i jaki przycisk zostal wcisniety
       for i:=2 to 5 do
       if (al_mouse_y < i*100+80) and (al_mouse_y>i*100) and (al_mouse_b = 1) and (al_mouse_x>380) and (al_mouse_x<620) then
       begin
            tmp_button:=i-1;
            al_play_sample( al_load_sample( 'sounds/click_on.wav' ), 255, 127, 1000, false );
       end;

       klik:=0;

       //petla podswietlajaca i odtwarzajaca odpowiedni dzwiek po najechaniu myszka
       for i:=2 to 5 do
       if (al_mouse_y < i*100+80) and (al_mouse_y>i*100) and (al_mouse_x>380) and (al_mouse_x<620) then
       begin
           if pressed then
           begin
               al_play_sample( al_load_sample( 'sounds/click_on.wav' ), 255, 127, 1000, false );
               pressed:=false;
           end;
           przycisk:=al_load_bitmap('buttons/pressed.bmp',@al_default_palette);
           al_masked_blit( przycisk,menu, 0, 0, 380, 200+(i-2)*100, przycisk^.w, przycisk^.h );
           al_blit( menu, al_screen, 0, 0, 0, 0, menu^.w, menu^.h );
       end
       else
       begin
           Inc(klik);
           przycisk:=al_load_bitmap('buttons/unpressed.bmp',@al_default_palette);
           al_masked_blit( przycisk,menu, 0, 0, 380, 200+(i-2)*100, przycisk^.w, przycisk^.h );
           al_blit( menu, al_screen, 0, 0, 0, 0, menu^.w, menu^.h );
       end;

       //jesli myszka teraz nie jest na zadnym klawiszu to w nastepnej petli mozna odtworzyc dzwiek najechania na przycisk
       //jesli myszka jest na przycisku to w nastepnej petli nie odtwarzaj dzwieku
       if klik = 4 then pressed:=true;

       menus:=tmp_button;
  end;
  until tmp_button <> 0;
end;

begin
  //ladujemy niezbedna dla allegro funkcje
  inicjalizacja;

  //tworzymy odpowiednie bufory
  bufor:= al_create_bitmap(1000,585);
  gui:= al_create_bitmap(1000,65);
  pauza:= al_create_bitmap(300,300);
  highscore:= al_create_bitmap(1000,650);
  formularz:= al_create_bitmap(300,300);

  //czyscimy bufor do gry
  al_clear_to_color(bufor, al_makecol(10,10,10));

  //sprawdzamy jaki przycisk wcisnieto az do wcisniecia przycisku wyjscia
  button:=0;
  while button <>4 do
  begin
       if button = 1 then
       begin
            multi:=false;
	    gra(button);
       end;
       if button = 2 then
	   begin
	        multi:=true;
		gra(button);
	   end;
       if button = 3 then
	   begin
	        print_highscore;
	   end;
       //zapetlamy menu
       if button<5 then button:=menus
       //jesli gracz chce zagrac jeszcze raz to odpowiednio ustawiamy nr przycisku
       else if button = 5 then button:= 1
       else button:= 2;
  end;


  //wylaczamy biblioteke allegro
  al_exit;

end.

