grammar Act;

defproc_or_cell
	: 	template_spec? 'defproc'  ID ('('port_formal_list ')')? proc_body
          	;
template_spec
   	: 	'export'
                	|	 'export'? 'template' '<' param_inst_list ('|' param_inst_list)? '>'
                	;
param_inst_list
   	:	param_inst (';' param_inst)*
   	;

param_inst	: 	param_type id_list	
            	 ;
param_type
  	: 	'pint'
             	| 	'pints'
             	| 	'pbool'
             	| 	'preal'
             	| 	'ptype' '<' physical_inst_type '>'
             	;
             	
port_formal_list
   	: 	single_port_item (';' single_port_item)*
                   	;

single_port_item
	: 	'+'? physical_inst_type id_list
                   	;
                   	
proc_body: ';'
         | '{' def_body '}'
         ;
         
def_body	:	base_item*;

base_item	:	instance
	|	connection
	|	alias
	|	language_body
	|	loop
	|	conditional
	;

physical_inst_type
	: 	data_type
                     | 	chan_type
                     | 	user_type
                     ;
                     
 T_INT	: 	'int'
        	| 	'ints'
        	;

 data_type	: 	T_INT chan_dir? ('<' wint_expr '>')?
            	|	'bool' chan_dir?
            	| 	'enum' chan_dir? '<' wint_expr '>'
           	 ;
           	 
chan_type: 'chan' chan_dir? '(' data_type (',' data_type)* ')'
         ;
         
 user_type: qualified_type template_args? chan_dir?
         ;

template_args: '<' { array_expr ',' }* '>'
             ;

qualified_type:  '::'? ID ( '::' ID)*
              ;

           	 
    chan_dir: '?'
           | '!'
           | '?!'
           | '!?'
           ;


   id_list: { ID [ dense_range ] "," }**
          ;

	
lang_prs	:	'prs' supply_spec? '{'
	;

supply_spec	: 	'<' bool_expr_id (',' bool_expr_id ) ( '|' bool_expr_id ',' bool_expr_id )? '>'
	;
             
bool_expr_id	: 	expr_id
	;
expr_id	:	base_id ('.' base_id)*
	;
base_id	:	ID sparse_range?
	;
sparse_range
	:	('[' wint_expr ('..' wint_expr)? ']')+
                   	;
wint_expr
	:	INT  | ID
	;
	

ID  :	('a'..'z'|'A'..'Z'|'_') ('a'..'z'|'A'..'Z'|'0'..'9'|'_')*
    ;

INT :	'0'..'9'+
    ;

COMMENT
    :   '//' ~('\n'|'\r')* '\r'? '\n' {$channel=HIDDEN;}
    |   '/*' ( options {greedy=false;} : . )* '*/' {$channel=HIDDEN;}
    ;

WS  :   ( ' '
        | '\t'
        | '\r'
        | '\n'
        ) {$channel=HIDDEN;}
    ;

