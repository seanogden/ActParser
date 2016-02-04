parser grammar ExprParser;

options{
k=2;
}

parExpression
    :   LPAREN expression RPAREN
    ;
    
expressionList
    :   expression (COMMA expression)*
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
    :   EQUAL
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
    :   PLUS unaryExpression
    |   DASH unaryExpression
    |   INC unaryExpression
    |   DEC unaryExpression
    |   unaryExpressionNotPlusMinus
    ;

unaryExpressionNotPlusMinus
    :   TILDE unaryExpression
    |   BANG unaryExpression
    //XXX:  Make sure this actually works.  Should be primary (INC|DEC)?, but antlr didn't like that.
    //      This compiles OK, but does it always just match primary and ignore INC and DEC?
    |   primary
    |   primary INC
    |   primary DEC 
    ;
    
primary
    :   parExpression(options{greedy=true;}: DOT ID)* identifierSuffix?
    |   literal
    |   ID (options{greedy=true;}: DOT ID)* identifierSuffix?
    ;
    
identifierSuffix
    :   (options{greedy=true;}: LBRAC expression RBRAC)+
    |   arguments
    ;
    
arguments
    :   LPAREN expressionList? RPAREN
    ;

literal 
    :   int
    |   FLOAT
    |   CHAR
    |   STRING
    |   bool
    ;
    
int
    :  DecimalLiteral
    ;

bool
    :  TRUE
    |  FALSE
    ;
    
