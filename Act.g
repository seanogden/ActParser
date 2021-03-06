grammar Act;
options { backtrack = true; }
import ExprParser, ExprLexer;

toplevel
	:	imports_opens? body?
	;
imports_opens
	:	import_open_item+
	;
	
import_open_item
	:	import_item
	|	open_item
	;
	
import_item
	:	IMPORT STRING SEMICOLON
	|	IMPORT qualified_ns (RIGHTARROW ID)? SEMICOLON
	;
open_item
	:	OPEN qualified_ns (RIGHTARROW ID)? SEMICOLON
	;
	
qualified_ns
	:	COLONCOLON? ID (COLONCOLON ID)*
	;
	
body
	:	body_item+
	;
	
body_item
	:	namespace_management
	|	base_item
	|	definition
	;
	
ns_body
	:	ns_body_item+
	;
	
ns_body_item
	:	definition
	|	namespace_management
	;

namespace_management
	:	EXPORT? NAMESPACE ID LBRACE ns_body? RBRACE
	;
	
definition
	:	(template_spec? DEFPROC)=>defproc_or_cell
	|	(template_spec? DEFTYPE)=>defdata
	|	defchan
	|	defenum
	|	deffunc
	;
	
defchan:  template_spec? DEFCHAN ID is_a physical_inst_type
           ( LPAREN port_formal_list RPAREN )? chan_body
       ;

chan_body: SEMICOLON
         | LBRACE base_body methods_body? RBRACE
         ;

defenum: DEFENUM ID enum_body
       ;

enum_body: SEMICOLON
         | LBRACE bare_id_list RBRACE SEMICOLON
         ;

bare_id_list: ID (COMMA ID)*
            ;

deffunc: FUNCTION ID LPAREN param_inst (SEMICOLON param_inst)* RPAREN COLON param_type func_body
       ;

func_body: SEMICOLON
         | LBRACE RBRACE
         ;


defdata: template_spec? DEFTYPE ID is_a physical_inst_type
           (LPAREN port_formal_list RPAREN)? data_body
       ;

is_a: ISA
    | EQUAL
    ;
    
data_body: SEMICOLON
         | LBRACE base_body methods_body? RBRACE
         ;

methods_body: METHODS LBRACE method_list? RBRACE
            ;

method_list: (ID LBRACE hse_body RBRACE)+
          ;

base_body: lang_spec base_body
         | alias base_body
         |
         ;



defproc_or_cell
	: 	template_spec? DEFPROC  ID (LPAREN port_formal_list RPAREN)? proc_body
          	;
template_spec
   	: 	EXPORT
        |	EXPORT? TEMPLATE LT param_inst_list (OR param_inst_list)? GT
        ;
param_inst_list
   	:	param_inst (SEMICOLON param_inst)*
   	;

param_inst	: 	param_type id_list	
            	 ;
param_type
  	: 	PINT
             	| 	PINTS
             	| 	PBOOL
             	| 	PREAL
             	| 	PTYPE LT physical_inst_type GT
             	;
             	
port_formal_list
   	: 	single_port_item (SEMICOLON single_port_item)*
                   	;

single_port_item
	: 	PLUS? physical_inst_type id_list
                   	;
                   	
proc_body: SEMICOLON
         | LBRACE def_body RBRACE
         ;
         
def_body
	:	base_item*
	;

base_item
	:	instance
	|	connection
	|	alias
	|	language_body
	|	loop
	|	conditional
	; 

conditional
	:	RBRAC guarded_cmds LBRAC
	;
	
guarded_cmds
	:	gc_1 (THICKBAR gc_1)*
	;
gc_1
	:	wbool_expr RIGHTARROW base_item+
	|	ELSE RIGHTARROW base_item+
	;
	
loop: LPAREN SEMICOLON ID COLON wint_expr
        ( DOTDOT wint_expr )? COLON base_item+ RPAREN
    ;

language_body
	:	lang_prs
	|	lang_chp
	|	lang_hse
	|	lang_spec
	|	lang_size
	;
alias
	:	array_expr (EQUAL array_expr)+
	;
	
connection
	:	special_connection_id SEMICOLON
	;
	 
instance
	:	PLUS? inst_type instance_id (COMMA instance_id)* SEMICOLON
	;
inst_type
	:	physical_inst_type
	|	param_type
	;
instance_id: ID sparse_range? ( LPAREN port_conn_spec RPAREN )?
               ( ATMARK attr_list )? opt_extra_conn 
           ;
opt_extra_conn
	: 	(EQUAL array_expr)*
	;

	
special_connection_id: ID dense_range? LPAREN port_conn_spec RPAREN
                         (ATMARK attr_list)?
                     | ID dense_range? ATMARK attr_list
                     ;

port_conn_spec: opt_array_expr_list
              | DOT ID EQUAL array_expr (COMMA DOT ID EQUAL array_expr)*
              ;

              
opt_array_expr_list
	:	array_expr? (COMMA array_expr?)*
	;

array_expr: array_term (HASH array_term)*
          ;
          
array_term: LBRACE array_expr (COMMA array_expr)* RBRACE
          | w_expr
          ;

dense_range
	:	(options {greedy=true;}: RBRAC wint_expr LBRAC)+
	;
	
attr_list
	: 	RBRAC ID EQUAL w_expr (SEMICOLON ID EQUAL w_expr)* LBRAC
	;
	
physical_inst_type
	: 	data_type
        | 	chan_type
        | 	user_type
        ;
                     
 t_int	: 	T_INT
       	| 	T_INTS
        ;

 data_type	: 	t_int chan_dir? (LT wint_expr GT)?
            	|	T_BOOL chan_dir?
            	| 	T_ENUM chan_dir? LT wint_expr GT
           	 ;
           	 
chan_type: T_CHAN chan_dir? LPAREN data_type (COMMA data_type)* RPAREN
         ;
         
 user_type: qualified_type template_args? chan_dir?
         ;

template_args: LT array_expr (COMMA array_expr)* GT
             ;

qualified_type:  COLONCOLON? ID ( COLONCOLON ID)*
              ;

           	 
chan_dir	: QUESTION
           	| BANG
           	| QMARKBANG
           	| BANGQMARK
           	;


id_list: ID dense_range ( COMMA ID dense_range*)*
          ;

	

	
lang_chp: CHP supply_spec? LBRACE RBRACE
        ;

lang_hse: HSE supply_spec? LBRACE hse_block //end brace happens in HSE parser to mark where we return to this parser.
        ;

lang_prs: PRS supply_spec? LBRACE RBRACE
        ;

lang_spec: SPEC LBRACE RBRACE
	;
	
// $<spec

lang_size: SIZE LBRACE RBRACE
         ;

// $>


	
supply_spec	: 	LT bool_expr_id (COMMA bool_expr_id ) ( OR bool_expr_id COMMA bool_expr_id )? GT
	;
             
bool_expr_id	: 	expr_id
	;
expr_id	:	base_id (DOT base_id)*
	;
base_id	:	ID sparse_range?
	;
sparse_range
	:	(RBRAC wint_expr (DOTDOT wint_expr)? LBRAC)+
                   	;
//TODO: enforce integer expression here 
wint_expr
	:   int;	

w_expr 	: expression 
	;

//TODO:  enforce boolean expression here
wbool_expr
	:	TRUE;
	

// $<HSE

hse_block
	:	hse_body RBRACE
	;
	
hse_body: hse_body_item (SEMICOLON hse_body_item)*
        ;



hse_body_item: hse_assign_stmt (COMMA hse_assign_stmt)*
             | hse_loop_stmt
             | hse_select_stmt
             | SKIP
             | LPAREN hse_body RPAREN
             ;

hse_assign_stmt: expr_id dir
               ;

hse_select_stmt: RBRAC hse_guarded_cmd (THICKBAR hse_guarded_cmd)* LBRAC
               | RBRAC wbool_expr LBRAC
               ;

hse_guarded_cmd: wbool_expr RIGHTARROW hse_body
               | ELSE RIGHTARROW hse_body
               ;

hse_loop_stmt: STARLBRACKET hse_body LBRAC
             | STARLBRACKET hse_guarded_cmd (THICKBAR hse_guarded_cmd)* LBRAC
             ;

dir: PLUS
   | DASH
   ;
// $>

// $<CHP
chp_body: chp_comma_list (SEMICOLON chp_comma_list)*
        ;

chp_comma_list: chp_body_item (COMMA chp_body_item)*
              ;

chp_body_item: base_stmt
             | select_stmt
             | loop_stmt
             ;

base_stmt: send_stmt
         | recv_stmt
         | assign_stmt
         | SKIP
         | LPAREN chp_body RPAREN
         | ID LPAREN chp_log_item (COMMA chp_log_item)* RPAREN
         ;

chp_log_item: expr_id
            | STRING
            ;

send_stmt: expr_id BANG send_data
         ;

send_data: (LPAREN w_expr COMMA)=> LPAREN  expressionList RPAREN
         | w_expr
         ;

recv_stmt: expr_id QUESTION recv_id
         ;

recv_id: expr_id
       | LPAREN expr_id (COMMA expr_id)* RPAREN
       ;

assign_stmt: expr_id COLONEQUAL w_expr
           | expr_id dir
           ;

select_stmt: RBRAC guarded_cmd (THICKBAR guarded_cmd)* LBRAC
           | RBRAC wbool_expr LBRAC
           ;

guarded_cmd: wbool_expr RIGHTARROW chp_body
           | ELSE RIGHTARROW chp_body
           ;

loop_stmt: STARLBRACKET chp_body LBRAC
         | STARLBRACKET guarded_cmd (THICKBAR guarded_cmd)* LBRAC
         ;

// $>

// $<SPEC
spec_body: spec_body_item+
	;

spec_body_item: ID LPAREN bool_expr_id (COMMA bool_expr_id)* RPAREN
              | DOLLARLPAREN wbool_expr RPAREN
              ;
// $>





IMPORT
	:	'import'
	;

RIGHTARROW
	:	'->'
	;

OPEN
	:	'open'
	;

COLONCOLON
	:	'::'
	;

EXPORT
	:	'export'
	;

NAMESPACE
	:	'namespace'
	;

LBRACE
	:	'{'
	;

RBRACE
	:	'}'
	;

DEFPROC
	:	'defproc'
	;

DEFTYPE
	:	'deftype'
	;

DEFCHAN
	:	'defchan'
	;



DEFENUM
	:	'defenum'
	;

FUNCTION
	:	'function'
	;
	
ISA	:	'<:';

METHODS
	:	'methods'
	;

TEMPLATE
	:	'template'
	;

PINT
	:	'pint'
	;

PINTS
	:	'pints'
	;

PBOOL
	:	'pbool'
	;

PREAL
	:	'preal'
	;

PTYPE
	:	'ptype'
	;

ATMARK
	:	'@'
	;

HASH
	:	'#'
	;

T_INT
	:	'int'
	;

T_INTS
	:	'ints'
	;

T_BOOL
	:	'bool'
	;

T_ENUM
	:	'enum'
	;

T_CHAN
	:	'chan'
	;

ELSE
	:	'else'
	;

THICKBAR
	:	'[]'
	;

QMARKBANG
	:	'?!'
	;

BANGQMARK
	:	'!?'
	;

CHP
	:	'chp'
	;

HSE
	:	'hse'
	;

PRS
	:	'prs'
	;

SPEC
	:	'spec'
	;

SIZE
	:	'size'
	;

DOT
	:	'.'
	;

DOTDOT
	:	'..'
	;

SKIP
	:	'skip'
	;

STARLBRACKET
	:	'*['
	;


COLONEQUAL
	:	':='
	;

DOLLARLPAREN
	:	'$('
	;
	
SEMICOLON
	:	';';
	
fragment
HEX_DIGIT : ('0'..'9'|'a'..'f'|'A'..'F') ;

fragment
ESC_SEQ
    :   '\\' ('b'|'t'|'n'|'f'|'r'|'\"'|'\''|'\\')
    |   UNICODE_ESC
    |   OCTAL_ESC
    ;

fragment
OCTAL_ESC
    :   '\\' ('0'..'3') ('0'..'7') ('0'..'7')
    |   '\\' ('0'..'7') ('0'..'7')
    |   '\\' ('0'..'7')
    ;

fragment
UNICODE_ESC
    :   '\\' 'u' HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT
    ;














































INC	: 	'++';
DEC	:	'--';
PLUSEQ	:	'+=';
MINUSEQ	:	'-=';
TIMESEQ	:	'*=';
DIVEQ	:	'/=';
ANDEQ	:	'&=';
OREQ	:	'|=';
XOREQ	:	'^=';
MODEQ	:	'%=';
EQUAL	:	'=';
MOD	:	'%';
DASH	:	'-';
PLUS	:	'+';
STAR	:	'*';
SLASH	:	'/';
LSHIFT	:	'<<';
RSHIFT	:	'>>';
ANDAND	:	'&&';
OROR	:	'||';
QUESTION	:	'?';
COLON	:	':';
AND	:	'&';
OR	:	'|';
HAT	:	'^';
EQEQ	:	'==';
NOTEQ	:	'!=';
LEQ	:	'<=';
GEQ	:	'>=';
LT	:	'<';
GT	:	'>';
TRUE	:	'true';
FALSE	:	'false';
LBRAC	:	'[';
RBRAC	:	']';
LPAREN	:	'(';
RPAREN	:	')';
COMMA	:	',';
	
DecimalLiteral : ('0' | '1'..'9' '0'..'9'*) IntegerTypeSuffix? ;

fragment
IntegerTypeSuffix : ('l'|'L') ;

FLOAT
    :   ('0'..'9')+ '.' ('0'..'9')* Exponent? FloatTypeSuffix?
    |   '.' ('0'..'9')+ Exponent? FloatTypeSuffix?
    |   ('0'..'9')+ Exponent FloatTypeSuffix?
    |   ('0'..'9')+ FloatTypeSuffix
    ;

fragment
Exponent : ('e'|'E') ('+'|'-')? ('0'..'9')+ ;

fragment
FloatTypeSuffix : ('f'|'F'|'d'|'D') ;

CHAR
    :   '\'' ( EscapeSequence | ~('\''|'\\') ) '\''
    ;

STRING
    :  '"' ( EscapeSequence | ~('\\'|'"') )* '"'
    ;

fragment
EscapeSequence
    :   '\\' ('b'|'t'|'n'|'f'|'r'|'\"'|'\''|'\\')
    |   OctalEscape
    ;

fragment
OctalEscape
    :   '\\' ('0'..'3') ('0'..'7') ('0'..'7')
    |   '\\' ('0'..'7') ('0'..'7')
    |   '\\' ('0'..'7')
    ;
    
ID 
    :   LETTER (LETTER|DIGIT)*
    ;

/**I found this char range in JavaCC's grammar, but Letter and Digit overlap.
   Still works, but...
 */
fragment
LETTER
    :  '\u0024' |
       '\u0041'..'\u005a' |
       '\u005f' |
       '\u0061'..'\u007a' |
       '\u00c0'..'\u00d6' |
       '\u00d8'..'\u00f6' |
       '\u00f8'..'\u00ff' |
       '\u0100'..'\u1fff' |
       '\u3040'..'\u318f' |
       '\u3300'..'\u337f' |
       '\u3400'..'\u3d2d' |
       '\u4e00'..'\u9fff' |
       '\uf900'..'\ufaff'
    ;

fragment
DIGIT
    :  '\u0030'..'\u0039' |
       '\u0660'..'\u0669' |
       '\u06f0'..'\u06f9' |
       '\u0966'..'\u096f' |
       '\u09e6'..'\u09ef' |
       '\u0a66'..'\u0a6f' |
       '\u0ae6'..'\u0aef' |
       '\u0b66'..'\u0b6f' |
       '\u0be7'..'\u0bef' |
       '\u0c66'..'\u0c6f' |
       '\u0ce6'..'\u0cef' |
       '\u0d66'..'\u0d6f' |
       '\u0e50'..'\u0e59' |
       '\u0ed0'..'\u0ed9' |
       '\u1040'..'\u1049'
   ;

WS  :  (' '|'\r'|'\t'|'\u000C'|'\n') {$channel=HIDDEN;}
    ;

COMMENT
    :   '/*' ( options {greedy=false;} : . )* '*/' {$channel=HIDDEN;}
    ;

LINE_COMMENT
    : '//' ~('\n'|'\r')* '\r'? '\n' {$channel=HIDDEN;}
    ;
