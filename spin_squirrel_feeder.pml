/*
 * МОДЕЛЬ: Автомат выдачи корма для белок (SPIN)
 * Состоит из:
 *  1) Controller — управляющий алгоритм
 *  2) Sensors — датчики (кнопки выбора, карта/оплата, пополнение)
 *  3) Actuators — актуаторы (импульсы выдачи)
 *  4) Environment — внешняя среда (недетерминированные события, но с циклической справедливостью)
 */

mtype = {
  none, left, right,
  ev_select_left, ev_select_right, ev_card_present, ev_pay_ok, ev_restock_left, ev_restock_right,
  cmd_dispense_left, cmd_dispense_right
};

mtype selection = none;   /* текущий выбор пользователя */
mtype paid_for  = none;   /* оплата за какой товар зафиксирована */
byte stock_left  = 3;     /* запас левого лотка: 0..5 */
byte stock_right = 3;     /* запас правого лотка: 0..5 */
bool dispense_left_pulse  = false; /* «импульс» выдачи слева в текущем шаге */
bool dispense_right_pulse = false; /* «импульс» выдачи справа в текущем шаге */

chan env_to_sensors    = [0] of { mtype };
chan sensors_to_ctrl   = [8] of { mtype };
chan ctrl_to_actuators = [2] of { mtype };

active proctype Environment() {
  byte k = 0;
  do
  :: atomic {
      if
      :: (k % 6 == 0) -> env_to_sensors!ev_select_left
      :: (k % 6 == 1) -> env_to_sensors!ev_pay_ok
      :: (k % 6 == 2) -> env_to_sensors!ev_restock_right
      :: (k % 6 == 3) -> env_to_sensors!ev_select_right
      :: (k % 6 == 4) -> env_to_sensors!ev_pay_ok
      :: else         -> env_to_sensors!ev_restock_left
      fi;
      k++;

      if :: skip :: skip :: skip fi
    }
  od
}

active proctype Sensors() {
  mtype e;
  do
  :: env_to_sensors?e ->
      sensors_to_ctrl!e
  od
}

active proctype Actuators() {
  mtype cmd;
  do
  :: ctrl_to_actuators?cmd ->
      if
      :: cmd == cmd_dispense_left  -> skip
      :: cmd == cmd_dispense_right -> skip
      :: else -> skip
      fi
  od
}

active proctype Controller() {
  mtype e;
  byte tmp;

  do
  :: atomic {
      dispense_left_pulse  = false;
      dispense_right_pulse = false;

      if
      :: sensors_to_ctrl?e ->
          if
          :: e == ev_select_left ->
                if
                :: paid_for != none -> skip
                :: else             -> selection = left
                fi
          :: e == ev_select_right ->
                if
                :: paid_for != none -> skip
                :: else             -> selection = right
                fi
          :: e == ev_pay_ok ->
                if
                :: (paid_for == none && selection != none) -> paid_for = selection
                :: else -> skip
                fi
          :: e == ev_restock_left ->
                if
                :: stock_left < 5  -> stock_left++
                :: else            -> skip
                fi
          :: e == ev_restock_right ->
                if
                :: stock_right < 5 -> stock_right++
                :: else            -> skip
                fi
          :: else -> skip
          fi
      :: else -> skip
      fi;

      if
      :: (paid_for == left && selection == left && stock_left > 0) ->
            tmp = stock_left;
            dispense_left_pulse = true;
            ctrl_to_actuators!cmd_dispense_left;
            stock_left = stock_left - 1;
            assert(stock_left == tmp - 1);
            selection = none;
            paid_for  = none
      :: (paid_for == right && selection == right && stock_right > 0) ->
            tmp = stock_right;
            dispense_right_pulse = true;
            ctrl_to_actuators!cmd_dispense_right;
            stock_right = stock_right - 1;
            assert(stock_right == tmp - 1);
            selection = none;
            paid_for  = none
      :: else -> skip
      fi
    }
  od
}

/* -------------------- LTL-спецификации -------------------- */

/* SAFETY 1: Никогда не выдаём одновременно из обоих лотков */
ltl no_double_dispense {
  [] !(dispense_left_pulse && dispense_right_pulse)
}

/* SAFETY 2: Нельзя выдавать из пустого лотка */
ltl no_dispense_from_empty {
  [] ((stock_left == 0 -> !dispense_left_pulse) &&
      (stock_right == 0 -> !dispense_right_pulse))
}

/* LIVENESS: После оплаты выбранного товара при положительном запасе — рано или поздно выдача */
ltl eventual_dispense_after_pay {
  [] ( ((paid_for == left  && selection == left  && stock_left  > 0) -> <> (dispense_left_pulse)) &&
       ((paid_for == right && selection == right && stock_right > 0) -> <> (dispense_right_pulse)) )
}
