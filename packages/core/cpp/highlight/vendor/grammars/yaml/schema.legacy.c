#include <stdint.h>

#include <stdlib.h>

#define SCH_STT_FRZ -1

#define HAS_TIMESTAMP 1

typedef enum {
  RS_STR,
  RS_FLOAT,
  RS_INT,
  RS_BOOL,
  RS_NULL,
  RS_TIMESTAMP,
} ResultSchema;

static int8_t adv_sch_stt(int8_t sch_stt, int32_t cur_chr, ResultSchema *rlt_sch) {
  switch (sch_stt) {
    case SCH_STT_FRZ:
      break;
    case 0:
        if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 89;}
        if (cur_chr == '0') {*rlt_sch = RS_INT; return 75;}
        if (cur_chr == 'F') {*rlt_sch = RS_STR; return 13;}
        if (cur_chr == 'N') {*rlt_sch = RS_BOOL; return 70;}
        if (cur_chr == 'O') {*rlt_sch = RS_STR; return 17;}
        if (cur_chr == 'T') {*rlt_sch = RS_STR; return 24;}
        if (cur_chr == 'Y') {*rlt_sch = RS_BOOL; return 69;}
        if (cur_chr == 'f') {*rlt_sch = RS_STR; return 29;}
        if (cur_chr == 'n') {*rlt_sch = RS_BOOL; return 72;}
        if (cur_chr == 'o') {*rlt_sch = RS_STR; return 33;}
        if (cur_chr == 't') {*rlt_sch = RS_STR; return 40;}
        if (cur_chr == 'y') {*rlt_sch = RS_BOOL; return 71;}
        if (cur_chr == '~') {*rlt_sch = RS_NULL; return 67;}
        if (cur_chr == '+') {*rlt_sch = RS_STR; return 7;}
        if (cur_chr == '-') {*rlt_sch = RS_STR; return 7;}
        if (('1' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_INT; return 82;}
      break;
    case 1:
      if (cur_chr == '-') {*rlt_sch = RS_STR; return 53;}
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 50;}
      if (('0' <= cur_chr && cur_chr <= '9') ||
          cur_chr == '_') {*rlt_sch = RS_STR; return 6;}
      break;
    case 2:
      if (cur_chr == '-') {*rlt_sch = RS_STR; return 54;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 3;}
      break;
    case 3:
      if (cur_chr == '-') {*rlt_sch = RS_STR; return 60;}
      break;
    case 4:
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 50;}
      if (cur_chr == '_') {*rlt_sch = RS_STR; return 6;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 1;}
      break;
    case 5:
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 50;}
      if (cur_chr == '_') {*rlt_sch = RS_STR; return 6;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 4;}
      break;
    case 6:
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 50;}
      if (('0' <= cur_chr && cur_chr <= '9') ||
          cur_chr == '_') {*rlt_sch = RS_STR; return 6;}
      break;
    case 7:
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 90;}
      if (cur_chr == '0') {*rlt_sch = RS_INT; return 78;}
      if (('1' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_INT; return 83;}
      break;
    case 8:
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 93;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 50;}
      break;
    case 9:
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 93;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 50;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 8;}
      break;
    case 10:
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 61;}
      break;
    case 11:
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 61;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 10;}
      break;
    case 12:
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 62;}
      break;
    case 13:
      if (cur_chr == 'A') {*rlt_sch = RS_STR; return 20;}
      if (cur_chr == 'a') {*rlt_sch = RS_STR; return 36;}
      break;
    case 14:
      if (cur_chr == 'A') {*rlt_sch = RS_STR; return 22;}
      if (cur_chr == 'a') {*rlt_sch = RS_STR; return 22;}
      break;
    case 15:
      if (cur_chr == 'E') {*rlt_sch = RS_BOOL; return 68;}
      break;
    case 16:
      if (cur_chr == 'F') {*rlt_sch = RS_BOOL; return 68;}
      break;
    case 17:
      if (cur_chr == 'F') {*rlt_sch = RS_STR; return 16;}
      if (cur_chr == 'f') {*rlt_sch = RS_STR; return 32;}
      if (cur_chr == 'N' ||
          cur_chr == 'n') {*rlt_sch = RS_BOOL; return 68;}
      break;
    case 18:
      if (cur_chr == 'F') {*rlt_sch = RS_FLOAT; return 88;}
      break;
    case 19:
      if (cur_chr == 'L') {*rlt_sch = RS_NULL; return 67;}
      break;
    case 20:
      if (cur_chr == 'L') {*rlt_sch = RS_STR; return 26;}
      break;
    case 21:
      if (cur_chr == 'L') {*rlt_sch = RS_STR; return 19;}
      break;
    case 22:
      if (cur_chr == 'N') {*rlt_sch = RS_FLOAT; return 88;}
      break;
    case 23:
      if (cur_chr == 'N') {*rlt_sch = RS_STR; return 18;}
      if (cur_chr == 'n') {*rlt_sch = RS_STR; return 34;}
      break;
    case 24:
      if (cur_chr == 'R') {*rlt_sch = RS_STR; return 27;}
      if (cur_chr == 'r') {*rlt_sch = RS_STR; return 43;}
      break;
    case 25:
      if (cur_chr == 'S') {*rlt_sch = RS_BOOL; return 68;}
      break;
    case 26:
      if (cur_chr == 'S') {*rlt_sch = RS_STR; return 15;}
      break;
    case 27:
      if (cur_chr == 'U') {*rlt_sch = RS_STR; return 15;}
      break;
    case 28:
      if (cur_chr == 'Z') {*rlt_sch = RS_TIMESTAMP; return 94;}
      if (cur_chr == '\t' ||
          cur_chr == ' ') {*rlt_sch = RS_STR; return 28;}
      break;
    case 29:
      if (cur_chr == 'a') {*rlt_sch = RS_STR; return 36;}
      break;
    case 30:
      if (cur_chr == 'a') {*rlt_sch = RS_STR; return 38;}
      break;
    case 31:
      if (cur_chr == 'e') {*rlt_sch = RS_BOOL; return 68;}
      break;
    case 32:
      if (cur_chr == 'f') {*rlt_sch = RS_BOOL; return 68;}
      break;
    case 33:
      if (cur_chr == 'f') {*rlt_sch = RS_STR; return 32;}
      if (cur_chr == 'n') {*rlt_sch = RS_BOOL; return 68;}
      break;
    case 34:
      if (cur_chr == 'f') {*rlt_sch = RS_FLOAT; return 88;}
      break;
    case 35:
      if (cur_chr == 'l') {*rlt_sch = RS_NULL; return 67;}
      break;
    case 36:
      if (cur_chr == 'l') {*rlt_sch = RS_STR; return 42;}
      break;
    case 37:
      if (cur_chr == 'l') {*rlt_sch = RS_STR; return 35;}
      break;
    case 38:
      if (cur_chr == 'n') {*rlt_sch = RS_FLOAT; return 88;}
      break;
    case 39:
      if (cur_chr == 'n') {*rlt_sch = RS_STR; return 34;}
      break;
    case 40:
      if (cur_chr == 'r') {*rlt_sch = RS_STR; return 43;}
      break;
    case 41:
      if (cur_chr == 's') {*rlt_sch = RS_BOOL; return 68;}
      break;
    case 42:
      if (cur_chr == 's') {*rlt_sch = RS_STR; return 31;}
      break;
    case 43:
      if (cur_chr == 'u') {*rlt_sch = RS_STR; return 31;}
      break;
    case 44:
      if (cur_chr == '\t' ||
          cur_chr == ' ') {*rlt_sch = RS_STR; return 47;}
      if (cur_chr == 'T' ||
          cur_chr == 't') {*rlt_sch = RS_STR; return 55;}
      break;
    case 45:
      if (cur_chr == '\t' ||
          cur_chr == ' ') {*rlt_sch = RS_STR; return 47;}
      if (cur_chr == 'T' ||
          cur_chr == 't') {*rlt_sch = RS_STR; return 55;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 44;}
      break;
    case 46:
      if (cur_chr == '\t' ||
          cur_chr == ' ') {*rlt_sch = RS_STR; return 47;}
      if (cur_chr == 'T' ||
          cur_chr == 't') {*rlt_sch = RS_STR; return 55;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_TIMESTAMP; return 99;}
      break;
    case 47:
      if (cur_chr == '\t' ||
          cur_chr == ' ') {*rlt_sch = RS_STR; return 47;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 11;}
      break;
    case 48:
      if (cur_chr == '+' ||
          cur_chr == '-') {*rlt_sch = RS_STR; return 52;}
      break;
    case 49:
      if (cur_chr == '0' ||
          cur_chr == '1' ||
          cur_chr == '_') {*rlt_sch = RS_INT; return 86;}
      break;
    case 50:
      if (('6' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 8;}
      if (('0' <= cur_chr && cur_chr <= '5')) {*rlt_sch = RS_STR; return 9;}
      break;
    case 51:
      if (('6' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_INT; return 84;}
      if (('0' <= cur_chr && cur_chr <= '5')) {*rlt_sch = RS_INT; return 85;}
      break;
    case 52:
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_FLOAT; return 92;}
      break;
    case 53:
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 2;}
      break;
    case 54:
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 45;}
      break;
    case 55:
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 11;}
      break;
    case 56:
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_TIMESTAMP; return 95;}
      break;
    case 57:
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_TIMESTAMP; return 94;}
      break;
    case 58:
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_TIMESTAMP; return 98;}
      break;
    case 59:
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_TIMESTAMP; return 97;}
      break;
    case 60:
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 46;}
      break;
    case 61:
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 64;}
      break;
    case 62:
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 56;}
      break;
    case 63:
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 57;}
      break;
    case 64:
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_STR; return 12;}
      break;
    case 65:
      if (('0' <= cur_chr && cur_chr <= '9') ||
          ('A' <= cur_chr && cur_chr <= 'F') ||
          cur_chr == '_' ||
          ('a' <= cur_chr && cur_chr <= 'f')) {*rlt_sch = RS_INT; return 87;}
      break;
    case 66:
      abort();
      break;
    case 67:
      *rlt_sch = RS_NULL;
      break;
    case 68:
      *rlt_sch = RS_BOOL;
      break;
    case 69:
      *rlt_sch = RS_BOOL;
      if (cur_chr == 'E') {*rlt_sch = RS_STR; return 25;}
      if (cur_chr == 'e') {*rlt_sch = RS_STR; return 41;}
      break;
    case 70:
      *rlt_sch = RS_BOOL;
      if (cur_chr == 'U') {*rlt_sch = RS_STR; return 21;}
      if (cur_chr == 'u') {*rlt_sch = RS_STR; return 37;}
      if (cur_chr == 'O' ||
          cur_chr == 'o') {*rlt_sch = RS_BOOL; return 68;}
      break;
    case 71:
      *rlt_sch = RS_BOOL;
      if (cur_chr == 'e') {*rlt_sch = RS_STR; return 41;}
      break;
    case 72:
      *rlt_sch = RS_BOOL;
      if (cur_chr == 'o') {*rlt_sch = RS_BOOL; return 68;}
      if (cur_chr == 'u') {*rlt_sch = RS_STR; return 37;}
      break;
    case 73:
      *rlt_sch = RS_INT;
      if (cur_chr == '-') {*rlt_sch = RS_STR; return 53;}
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 50;}
      if (cur_chr == '8' ||
          cur_chr == '9') {*rlt_sch = RS_STR; return 6;}
      if (('0' <= cur_chr && cur_chr <= '7') ||
          cur_chr == '_') {*rlt_sch = RS_INT; return 79;}
      break;
    case 74:
      *rlt_sch = RS_INT;
      if (cur_chr == '-') {*rlt_sch = RS_STR; return 53;}
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 51;}
      if (('0' <= cur_chr && cur_chr <= '9') ||
          cur_chr == '_') {*rlt_sch = RS_INT; return 83;}
      break;
    case 75:
      *rlt_sch = RS_INT;
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 50;}
      if (cur_chr == '_') {*rlt_sch = RS_INT; return 79;}
      if (cur_chr == 'b') {*rlt_sch = RS_STR; return 49;}
      if (cur_chr == 'x') {*rlt_sch = RS_STR; return 65;}
      if (cur_chr == '8' ||
          cur_chr == '9') {*rlt_sch = RS_STR; return 5;}
      if (('0' <= cur_chr && cur_chr <= '7')) {*rlt_sch = RS_INT; return 77;}
      break;
    case 76:
      *rlt_sch = RS_INT;
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 50;}
      if (cur_chr == '_') {*rlt_sch = RS_INT; return 79;}
      if (cur_chr == '8' ||
          cur_chr == '9') {*rlt_sch = RS_STR; return 1;}
      if (('0' <= cur_chr && cur_chr <= '7')) {*rlt_sch = RS_INT; return 73;}
      break;
    case 77:
      *rlt_sch = RS_INT;
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 50;}
      if (cur_chr == '_') {*rlt_sch = RS_INT; return 79;}
      if (cur_chr == '8' ||
          cur_chr == '9') {*rlt_sch = RS_STR; return 4;}
      if (('0' <= cur_chr && cur_chr <= '7')) {*rlt_sch = RS_INT; return 76;}
      break;
    case 78:
      *rlt_sch = RS_INT;
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 50;}
      if (cur_chr == 'b') {*rlt_sch = RS_STR; return 49;}
      if (cur_chr == 'x') {*rlt_sch = RS_STR; return 65;}
      if (cur_chr == '8' ||
          cur_chr == '9') {*rlt_sch = RS_STR; return 6;}
      if (('0' <= cur_chr && cur_chr <= '7') ||
          cur_chr == '_') {*rlt_sch = RS_INT; return 79;}
      break;
    case 79:
      *rlt_sch = RS_INT;
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 50;}
      if (cur_chr == '8' ||
          cur_chr == '9') {*rlt_sch = RS_STR; return 6;}
      if (('0' <= cur_chr && cur_chr <= '7') ||
          cur_chr == '_') {*rlt_sch = RS_INT; return 79;}
      break;
    case 80:
      *rlt_sch = RS_INT;
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 51;}
      if (cur_chr == '_') {*rlt_sch = RS_INT; return 83;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_INT; return 74;}
      break;
    case 81:
      *rlt_sch = RS_INT;
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 51;}
      if (cur_chr == '_') {*rlt_sch = RS_INT; return 83;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_INT; return 80;}
      break;
    case 82:
      *rlt_sch = RS_INT;
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 51;}
      if (cur_chr == '_') {*rlt_sch = RS_INT; return 83;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_INT; return 81;}
      break;
    case 83:
      *rlt_sch = RS_INT;
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 91;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 51;}
      if (('0' <= cur_chr && cur_chr <= '9') ||
          cur_chr == '_') {*rlt_sch = RS_INT; return 83;}
      break;
    case 84:
      *rlt_sch = RS_INT;
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 93;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 51;}
      break;
    case 85:
      *rlt_sch = RS_INT;
      if (cur_chr == '.') {*rlt_sch = RS_FLOAT; return 93;}
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 51;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_INT; return 84;}
      break;
    case 86:
      *rlt_sch = RS_INT;
      if (cur_chr == '0' ||
          cur_chr == '1' ||
          cur_chr == '_') {*rlt_sch = RS_INT; return 86;}
      break;
    case 87:
      *rlt_sch = RS_INT;
      if (('0' <= cur_chr && cur_chr <= '9') ||
          ('A' <= cur_chr && cur_chr <= 'F') ||
          cur_chr == '_' ||
          ('a' <= cur_chr && cur_chr <= 'f')) {*rlt_sch = RS_INT; return 87;}
      break;
    case 88:
      *rlt_sch = RS_FLOAT;
      break;
    case 89:
      *rlt_sch = RS_FLOAT;
      if (cur_chr == 'I') {*rlt_sch = RS_STR; return 23;}
      if (cur_chr == 'N') {*rlt_sch = RS_STR; return 14;}
      if (cur_chr == 'i') {*rlt_sch = RS_STR; return 39;}
      if (cur_chr == 'n') {*rlt_sch = RS_STR; return 30;}
      if (cur_chr == 'E' ||
          cur_chr == 'e') {*rlt_sch = RS_STR; return 48;}
      if (cur_chr == '.' ||
          ('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_FLOAT; return 91;}
      break;
    case 90:
      *rlt_sch = RS_FLOAT;
      if (cur_chr == 'I') {*rlt_sch = RS_STR; return 23;}
      if (cur_chr == 'i') {*rlt_sch = RS_STR; return 39;}
      if (cur_chr == 'E' ||
          cur_chr == 'e') {*rlt_sch = RS_STR; return 48;}
      if (cur_chr == '.' ||
          ('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_FLOAT; return 91;}
      break;
    case 91:
      *rlt_sch = RS_FLOAT;
      if (cur_chr == 'E' ||
          cur_chr == 'e') {*rlt_sch = RS_STR; return 48;}
      if (cur_chr == '.' ||
          ('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_FLOAT; return 91;}
      break;
    case 92:
      *rlt_sch = RS_FLOAT;
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_FLOAT; return 92;}
      break;
    case 93:
      *rlt_sch = RS_FLOAT;
      if (('0' <= cur_chr && cur_chr <= '9') ||
          cur_chr == '_') {*rlt_sch = RS_FLOAT; return 93;}
      break;
    case 94:
      *rlt_sch = RS_TIMESTAMP;
      break;
    case 95:
      *rlt_sch = RS_TIMESTAMP;
      if (cur_chr == '.') {*rlt_sch = RS_STR; return 58;}
      if (cur_chr == 'Z') {*rlt_sch = RS_TIMESTAMP; return 94;}
      if (cur_chr == '\t' ||
          cur_chr == ' ') {*rlt_sch = RS_STR; return 28;}
      if (cur_chr == '+' ||
          cur_chr == '-') {*rlt_sch = RS_STR; return 59;}
      break;
    case 96:
      *rlt_sch = RS_TIMESTAMP;
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 63;}
      break;
    case 97:
      *rlt_sch = RS_TIMESTAMP;
      if (cur_chr == ':') {*rlt_sch = RS_STR; return 63;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_TIMESTAMP; return 96;}
      break;
    case 98:
      *rlt_sch = RS_TIMESTAMP;
      if (cur_chr == 'Z') {*rlt_sch = RS_TIMESTAMP; return 94;}
      if (cur_chr == '\t' ||
          cur_chr == ' ') {*rlt_sch = RS_STR; return 28;}
      if (cur_chr == '+' ||
          cur_chr == '-') {*rlt_sch = RS_STR; return 59;}
      if (('0' <= cur_chr && cur_chr <= '9')) {*rlt_sch = RS_TIMESTAMP; return 98;}
      break;
    case 99:
      *rlt_sch = RS_TIMESTAMP;
      if (cur_chr == '\t' ||
          cur_chr == ' ') {*rlt_sch = RS_STR; return 47;}
      if (cur_chr == 'T' ||
          cur_chr == 't') {*rlt_sch = RS_STR; return 55;}
      break;
    default:
      *rlt_sch = RS_STR;
      return SCH_STT_FRZ;
  }
  if (cur_chr != '\r' && cur_chr != '\n' && cur_chr != ' ' && cur_chr != 0) *rlt_sch = RS_STR;
  return SCH_STT_FRZ;
}
