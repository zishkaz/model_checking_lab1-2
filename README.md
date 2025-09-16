# Лабораторная работа №1 — Автомат выдачи корма для белок (nuXmv)

> Система: **торговый автомат с двумя лотками** (лесные орехи — 50₽, кедровые — 75₽).
> Пользователь выбирает товар, прикладывает карту, при успешной оплате и наличии
> товара — открывается соответствующий затвор (выдача порции). При пустом лотке
> выдача блокируется до пополнения.

---

## Соответствие требованиям

- [✓] **Процесс управляющего алгоритма** — модуль `feeder_controller`
- [✓] **Процессы датчиков/индикаторов** — обобщённый модуль `sensor` для:
  выбор товара (левая/правая кнопка), картридер (карта приложена/оплата успешна),
  пополнение лотков (сигналы пополнения)
- [✓] **Процессы актуаторов** — реализованы в контроллере (`dispense_left/right`)
- [✓] **Процесс пользователя/среды** — модуль `environment` с недетерминированной
  генерацией событий (нажимает кнопки, прикладывает карту, пополняет лотки)
- [✓] **Бесконечная работа** — за счёт `FAIRNESS/ JUSTICE` условий в `environment` и
  системе (события пользователя и пополнения происходят время от времени)

---

## Свойства (проверяются в конце файла `.smv`)

### Инварианты (safety)
1. **Никогда не выдаём обе порции одновременно**  
   `INVARSPEC !(controller.dispense_left & controller.dispense_right)`

2. **Выдача невозможна при пустом лотке**  
   `INVARSPEC controller.stock_left = 0 -> !controller.dispense_left`  
   `INVARSPEC controller.stock_right = 0 -> !controller.dispense_right`

### LTL (liveness / корректность переходов)
3. **После успешной оплаты выбранного товара — рано или поздно произойдёт выдача**  
   `LTLSPEC G (controller.paid_for = left  & controller.selection = left  & controller.stock_left  > 0 -> F controller.dispense_left)`  
   `LTLSPEC G (controller.paid_for = right & controller.selection = right & controller.stock_right > 0 -> F controller.dispense_right)`

4. **При выдаче запас убывает ровно на 1 в следующем состоянии**  
   `LTLSPEC G (controller.dispense_left  -> X controller.stock_left  = controller.stock_left  - 1)`  
   `LTLSPEC G (controller.dispense_right -> X controller.stock_right = controller.stock_right - 1)`

*Как минимум два свойства — safety — гарантированно выполняются, а liveness — при заданной справедливости событий среды.*
