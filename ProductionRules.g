grammar ProductionRules;


rules		:	rule+ '}'
		;
	
rule		:	prs_expr ARROW bool_expr_id dir
		;
	
/*prs_expr */	
prs_expr	:	prs_term ('|' prs_term)*
           	;
   
prs_term	:	prs_atom  ('&' ('{' dir prs_expr '}')? prs_atom)*
           	;
   
prs_atom	:	INV? prs_bb
           	;
   
prs_bb		: 	sized_id
                | 	'(' prs_expr ')'
                |	'@' ID
                |	'(' prs_op ID ':' wint_expr ( '..' wint_expr )? ':' prs_expr ')'
                ;
   
prs_op	: 	'&' ':'
         	| 	'|' ':'
        	;
   
bool_expr_id	: 	expr_id
               	;
   
size_spec	: 	'<' wint_expr (',' wint_expr)? ( ':' ID )? '>'
            	|
            	;

sized_id	:	bool_expr_id	 size_spec
		;
wint_expr	:	INT  | ID
		;
expr_id		:	base_id ('.' base_id)*
		;
base_id		:	ID sparse_range?
		;

sparse_range
		:	('[' wint_expr ('..' wint_expr)? ']')+
                ;

                  
 /*Lexer */

dir	:	('+'|'-')
	;
INV	:	'~'
	;
ARROW	:	'->'
	;
ID  	:	('a'..'z'|'A'..'Z'|'_') ('a'..'z'|'A'..'Z'|'0'..'9'|'_')*
    	;
INT	:	'0'..'9'+
   	;
WS  	:   	(' '|'\t'|'\r'|'\n') {$channel=HIDDEN;}
    	;


