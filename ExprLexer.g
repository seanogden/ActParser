lexer grammar ExprLexer;


TILDE:  '~';
BANG:   '!';
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
