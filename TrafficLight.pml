
chan TL1 = [1] of {byte};
chan TL2 = [1] of {byte};
chan TL3 = [1] of {byte};
chan TL4 = [1] of {byte};
chan TL5 = [1] of {byte};
chan TL6 = [1] of {byte};


byte n = 6;

// Номер светофора, который сейчас принимает решение
byte currentTurn = 1;

// Запросы машин на каждый светофор. 
// Первое число - число машин желающих вос-ться 1м светофором. Второе - на второй и т.д
byte queue [6]  = {0,0,0,0,0,0};


// Флаги, какие светофоры хотят загореться

// Размер N+1 как костыль для чистоты кода. В "proctype TrafficLight" - есть 3 аргумента с ключами потенциальных соперников (например для красного пути соперники - розовый, черный, пешеходы)
// Если соперников фактически меньше (только 2 например), передается индекс несуществующего светофора, который всегда == 0 и такие ключи игнорируются
short requests [7]  = {0,0,0,0,0,0};

// Статусы светофоров (зеленый - true, красный - false). 
// Светофоры только пишут свои статусы, на других не смотрят
bool statuses [6]  = {false, false, false, false, false, false};


proctype TrafficLight (byte number; byte nextNum; byte fProblem; byte sProblem; byte tProblem; chan tlChan){

    // Если true - светофор будет пропускать вперед тех соперников, у которых ключ больше,
    // иначе - тех, у кого меньше
    bool direction = true;
// Переменные для проверки и борьбы за ресурсы
    short fValue=0;
    short sValue=0;
    short tValue=0;
    short nValue = 0;

// Значение из канала, чтобы было куда читать
    byte aps =0;
    do
    //Если наступил ход этого светофора
        ::  currentTurn == number  ->
        if
        // Есть траффик для этого светофора
        ::    tlChan?aps->
        
                requests[0] = 0; // зануляем фиктивную переменную (на всякий случай)
                queue[number-1] = aps; // получаем машины, которые хотят проехать

                 // Логгирование состояний в начале хода    
                 atomic {  
                printf("\n\n");      
                printf("Start select proc for :%d\n", number);
                printf("Is green = %d\n", statuses[number-1]);
                printf("Has some cars = %d\n", queue[number-1]);
                printf("My request is: %d\n", requests[number]);
                 }

                if
                // Если до этого светофор горел зеленым
                    :: statuses[number-1] == true ->
                           requests [number] =0; //Светофор выходит из очереди на проезд
                           statuses[number-1] = false; // Меняет свой цвет на красный
                           printf ("Set color as red at %d\n", number);
                           printf("And now its request is: %d\n", requests[number]);
                    :: else -> skip;
                fi;

                

                
                if
                // Если светофор уже запросил проезд (прошел 1 круг после этого)
                :: requests[number] > 0  ->
                        if
                        // Если после опроса, нет других светофоров - соперников
                        :: (requests[fProblem] == 0  ) && 
                            (requests[sProblem] == 0 ) && 
                            (requests[tProblem] == 0  ) 
                            // У некоторых светофоров меньше трех пересечений, тогда аргументом _Problem передается маг. число - N+1 от номера
                            // Т.е эта ветка обрабатывает ситуации когда
                            // либо нет запроса на проезд по тому же маршруту, либо нет точки пересечения вообще
                            ->
                                statuses[number-1] = true; // Зажигается зеленый
                                queue[number-1] = 0; // Все ожидающие машины проезжают
                                printf ("Set color as green (no enemies) at %d\n", number);
                                direction = !direction; // Меняется функция для след. сравнений
                                currentTurn = nextNum // Передача хода соседу

                        // Если есть желающие проехать по тем же точкам, что и тек. светофор
                        :: else ->
                                // Смотрим кто из соперников тоже хочет проехать
                                // Для всех потенциальных соперников, смотрим, если он хочет проехать, то записываем его ключ для сравнения
                                // Иначе пишем ключ == тек. светофору (равенство ключей при сравнении игнорируется)
                                if // Первый соперник
                                    :: requests[fProblem] > 0 -> fValue = requests[fProblem];
                                    :: else -> fValue = 0;
                                fi;
                                if // Второй соперник
                                    :: requests[sProblem] >0 -> sValue = requests[sProblem];
                                    :: else -> sValue = 0;
                                fi;
                                if // Третий соперник
                                    :: requests[tProblem] >0 -> tValue = requests[tProblem];
                                    :: else -> tValue = 0;
                                fi

                                nValue = requests[number];
                                atomic {

                                printf("(%d) enemies are: %d,%d,%d\n", number, fProblem, sProblem, tProblem);
                                printf("And values for #%d : (%d) and for enemies are: %d,%d,%d\n", number, nValue, fValue, sValue, tValue);
                                }

                                // Теперь у нас 3 ключа светофоров, там хранятся либо ключи - соперники, либо текущий номер светофора
                                if 
                                            // Если есть соперники, которые больше меня, я их пропущу
                                            :: fValue > nValue || sValue > nValue || tValue > nValue ->
                                                    //Но из-за того, что я ждал, я повышу всем оценку. Максимальный и так выполнится, но он не станет победителем 2 раза подряд
                                                    requests[number] =  nValue + n; 
                                                    requests[fProblem] = fValue + n;
                                                    requests[sProblem] = sValue + n;
                                                    requests[tProblem] = tValue + n;
                                                    printf ("(%d) will wait for enemies \n", number);
                                                    printf("(%d) new value is (%d) and for enemies: %d,%d,%d\n",  number, requests[number], requests[fProblem], requests[sProblem], requests[tProblem]);
                                                    skip

                                            // Иначе светофор зажигается зеленым
                                            :: else ->
                                                 printf ("Set color as green as (%d) was MAX \n", number);
                                                 statuses[number-1] = true; // Зажигается зеленый
                                                 queue[number-1] = 0; // Все ожидающие машины проезжают
                                                 requests[number] = 1000 + number //Ставим максимум, чтобы никто не перекрыл

                                 fi;
                        atomic{
                            printf("Requests are 1 (%d), 2 (%d), 3 (%d), 4 (%d), 5 (%d), 6 (%d)\n", requests[1],requests[2],requests[3],requests[4],requests[5],requests[6]);
                        printf("Statuses are 1 (%d), 2 (%d), 3 (%d), 4 (%d), 5 (%d), 6 (%d)\n", statuses[0],statuses[1],statuses[2],statuses[3],statuses[4],statuses[5]);
                        printf("Cars waiting at 1 (%d), 2 (%d), 3 (%d), 4 (%d), 5 (%d), 6 (%d)\n", queue[0],queue[1],queue[2],queue[3],queue[4],queue[5]);
                        }
                        currentTurn = nextNum; // Передача хода соседу 
                        requests[0] = 0; // Если меняли фикт. поле - зануляем его


                        fi

                // Если светофор ранее не просился воспользоваться дорогой
                :: else ->

                // Данный if уже бесполезен, т.к. перешли на каналы, но удалять страшно :)
                        if
                         // И кто-то хочет воспользоваться этим светофором
                          :: queue[number-1] > 0 ->
                            // То, светофор заявляет, что  хотел бы загореться зеленым
                                requests[number] = number;
                                printf ("Ask to set color as green at %d\n", number);
                                skip;

                         // Иначе, ждем просьбы дальше (никогда не выполнится, см выше)
                         :: else -> 
                                   skip;
                         fi;
                         atomic{
                        printf("Requests are 1 (%d), 2 (%d), 3 (%d), 4 (%d), 5 (%d), 6 (%d)\n", requests[1],requests[2],requests[3],requests[4],requests[5],requests[6]);
                        printf("Statuses are 1 (%d), 2 (%d), 3 (%d), 4 (%d), 5 (%d), 6 (%d)\n", statuses[0],statuses[1],statuses[2],statuses[3],statuses[4],statuses[5]);
                        printf("Cars waiting at 1 (%d), 2 (%d), 3 (%d), 4 (%d), 5 (%d), 6 (%d)\n", queue[0],queue[1],queue[2],queue[3],queue[4],queue[5]);
                        }
                        currentTurn = nextNum;

                fi;
            fi;
    od
}

/// Отправляет траффик в каналы
proctype TrafficGenerator(){
    do
        :: TL1!1
        :: TL2!1
        :: TL3!1
        :: TL4!1
        :: TL5!1
        :: TL6!1
    od
}


init {
    run  TrafficLight (1, 2, 2, 3, 0, TL1); // Зеленый путь
    run  TrafficLight (2, 3, 1, 4, 0, TL2); // Розовый путь
    run  TrafficLight (3, 4, 6, 5, 1, TL3); // Синий путь
    run  TrafficLight (4, 5, 2, 6, 5, TL4); // Красный путь
    run  TrafficLight (5, 6, 3, 4, 0, TL5); // Пешеходный путь
    run  TrafficLight (6, 1, 3, 4, 0, TL6); // Черный путь

    run TrafficGenerator();

}


// Безопасность - нет пересечений между:

ltl s1 {
    [] (!(statuses [0] == true && statuses [1] == true)) // зеленый и розовый
};

ltl s2 {
    [] (! (statuses [0] == true && statuses [2] == true)) // зеленый и синий
};

ltl s3 {
   [] (! (statuses [5] == true && statuses [2] == true)) // синий и черный
};

ltl s4 {
   [] (! (statuses [4] == true && statuses [2] == true)) // синий и пешеход
};

ltl s5 {
   [] (! (statuses [1] == true && statuses [3] == true)) // розовый и красный
};

ltl s6 {
   [] (! (statuses [3] == true && statuses [4] == true)) // красный и пешеход
};

ltl s7 {
   [] (! (statuses [3] == true && statuses [5] == true)) // красный и черный
};


// Liveness - если есть запрос и горит красный, то рано или поздно загорится зеленый
ltl l1 {
        []( ( (queue[0] == 1 && statuses[0]==false) -> (<>(statuses[0]==true) )) )
};

ltl l2 {
        []( ( (queue[1] == 1 && statuses[1]==false) -> (<>(statuses[1]==true) )) )
};

ltl l3 {
        []( ( (queue[2] == 1 && statuses[2]==false) -> (<>(statuses[2]==true) )) )
};

ltl l4 {
        []( ( (queue[3] == 1 && statuses[3]==false) -> (<>(statuses[3]==true) )) )
};

ltl l5 {
        []( ( (queue[4] == 1 && statuses[4]==false) -> (<>(statuses[4]==true) )) )
};

ltl l6 {
        []( ( (queue[5] == 1 && statuses[5]==false) -> (<>(statuses[5]==true) )) )
};


// Честность 

ltl f1 {
    [](<>(statuses[0] == false))
};

ltl f2 {
    [](<>(statuses[1] == false))
};

ltl f3 {
    [](<>(statuses[2] == false))
};

ltl f4 {
    [](<>(statuses[3] == false))
};

ltl f5 {
    [](<>(statuses[4] == false))
};

ltl f6 {
    [](<>(statuses[5] == false))
};


// Одновременный проезд 