grammar Expr;

options{
k=2;
}

parExpression
    :   '(' expression ')'
    ;
    
expressionList
    :   expression (',' expression)*
    ;

statementExpression
    :   expression
    ;
    
constantExpression
    :   expression
    ;
 
expression
    :   conditionalExpression (options{greedy=true;}: assignmentOperator expression)?
    ;
    
assignmentOperator
    :   EQEQ
    |   PLUSEQ
    |   MINUSEQ
    |   TIMESEQ
    |   DIVEQ
    |   ANDEQ
    |   OREQ
    |   XOREQ
    |   MODEQ
    ;

conditionalExpression
    :   conditionalOrExpression ( QUESTION expression COLON expression )?
    ;
    
conditionalOrExpression
    :   conditionalAndExpression ( OROR conditionalAndExpression )*
    ;

conditionalAndExpression
    :   inclusiveOrExpression ( ANDAND inclusiveOrExpression )*
    ;

inclusiveOrExpression
    :   exclusiveOrExpression ( OR exclusiveOrExpression )*
    ;

exclusiveOrExpression
    :   andExpression ( HAT andExpression )*
    ;

andExpression
    :   equalityExpression ( AND equalityExpression )*
    ;

equalityExpression
    :   relationalExpression ( (EQEQ | NOTEQ) relationalExpression )*
    ;

relationalExpression
    :   shiftExpression ( relationalOp shiftExpression )*
    ;
 
relationalOp
    :   LEQ
    |   GEQ
    |   LT
    |   GT
    ;

shiftExpression
    :   additiveExpression ( shiftOp additiveExpression )*
    ;

shiftOp
    :   LSHIFT
    |   RSHIFT
    ;


additiveExpression
    :   multiplicativeExpression ( (PLUS | DASH) multiplicativeExpression )*
    ;

multiplicativeExpression
    :   unaryExpression ( ( STAR | SLASH | MOD ) unaryExpression )*
    ;
    
unaryExpression
    :   '+' unaryExpression
    |   '-' unaryExpression
    |   '++' unaryExpression
    |   '--' unaryExpression
    |   unaryExpressionNotPlusMinus
    ;

unaryExpressionNotPlusMinus
    :   '~' unaryExpression
    |   '!' unaryExpression
    |   primary (INC|DEC)?
    ;
    
primary
    :   parExpression(options{greedy=true;}: '.' ID)* identifierSuffix?
    |   literal
    |   ID (options{greedy=true;}: '.' ID)* identifierSuffix?
    ;
    
identifierSuffix
    :   (options{greedy=true;}: LBRAC expression RBRAC)+
    |   arguments
    ;
    
arguments
    :   '(' expressionList? ')'
    ;

literal 
    :   int
    |   FLOAT
    |   CHAR
    |   STRING
    |   bool
    ;
    
int
    :   HexLiteral
    |   OctalLiteral
    |   DecimalLiteral
    ;

bool
    :  TRUE
    |  FALSE
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
    
HexLiteral : '0' ('x'|'X') HexDigit+ IntegerTypeSuffix? ;

DecimalLiteral : ('0' | '1'..'9' '0'..'9'*) IntegerTypeSuffix? ;

OctalLiteral : '0' ('0'..'7')+ IntegerTypeSuffix? ;

fragment
HexDigit : ('0'..'9'|'a'..'f'|'A'..'F') ;

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
    |   UnicodeEscape
    |   OctalEscape
    ;

fragment
OctalEscape
    :   '\\' ('0'..'3') ('0'..'7') ('0'..'7')
    |   '\\' ('0'..'7') ('0'..'7')
    |   '\\' ('0'..'7')
    ;

fragment
UnicodeEscape
    :   '\\' 'u' HexDigit HexDigit HexDigit HexDigit
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