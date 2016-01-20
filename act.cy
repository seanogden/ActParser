#line 1 "act.m4"
/*************************************************************************
 *
 *  Copyright (c) 2011-2013 Rajit Manohar
 *  All Rights Reserved
 *
 **************************************************************************
 */

/*------------------------------------------------------------------------
 *
 *  Act top-level pgen file
 *
 *------------------------------------------------------------------------
 */

%type[X] {{ ActTree ActRet }};

/*------------------------------------------------------------------------
 *
 * Grammar
 *
 *------------------------------------------------------------------------
 */
toplevel: [ imports_opens ] [ body ]
{{X:
    OPT_FREE ($1);

    if (!OPT_EMPTY ($2)) {
      ActRet *r;

      r = OPT_VALUE ($2);
      $A(r->type == R_ACT_BODY);
      $0->curns->setBody (r->u.body);
      FREE (r);
    }
    OPT_FREE ($2);
    return NULL;
}}
;

imports_opens
: import_open_item imports_opens
| import_open_item
;

body[ActBody *]
: body_item body
{{X:
    if ($1 == NULL) {
      return $2;
    }
    if ($2 == NULL) {
      return $1;
    }
    $1->Append ($2);
    return $1;
}}
| body_item
{{X: return $1; }}
;

ns_body
: ns_body_item ns_body
| ns_body_item
;

ns_body_item
: definition
| namespace_management
  /* XXX:
       Here we should add: 
       1. connections
       2. param type instances
       3. data or channel type instances
  */
;

body_item[ActBody *]
: namespace_management
{{X: return NULL; }}
| base_item
{{X: return $1; }}
| definition
{{X: return NULL; }}
;

import_open_item: import_item  | open_item ;

/* namespaces */
#line 1 "namespaces.m4"
/*************************************************************************
 *
 *  Copyright (c) 2012 Rajit Manohar
 *  All Rights Reserved
 *
 **************************************************************************
 */

/*------------------------------------------------------------------------
 *
 *  
 *   Namespace management
 *
 *
 *------------------------------------------------------------------------
 */

import_item: "import" STRING ";"
{{X:
    act_Token *t;
    char *tmp;
    char *s;

    MALLOC (tmp, char, strlen ($2)-1);
    strncpy (tmp, $2+1, strlen($2)-2);
    tmp[strlen ($2)-2] = '\0';
    s = path_open (tmp);
    FREE (tmp);
    
    /* Check if this is a recursive call within another import of the
       same file. */
    if (act_pending_import (s)) {
      $e("Your file has a recursive import of file `%s'\n", s);
      act_print_import_stack (stderr);
      exit (1);
    }

    /* If the file has already been imported in the past, then we can
       ignore this import statement */
    if (act_isimported (s)) {
      FREE (s);
      return NULL;
    }

    /* Record the fact that we are in the middle of importing this
       file */
    act_push_import (s);

    /* Process the new file */
    TRY {
      t = act_parse (s);
      act_walk_X ($0, t);
      act_parse_free (t);
    } CATCH {
      EXCEPT_SWITCH {
      default:
	$W("while processing `import' on file `%s'\n", s);
	FREE (s);
	except_throw (except_type (), except_arg ());
	break;
      }
    }

    /* Mark the file as imported, but no longer open */
    act_pop_import (s);
    FREE (s);

    return NULL;
}}
| "import" [ "::" ] { ID "::" }* [ "->" ID ] ";"
{{X:
    char *s, *tmp;
    int len, len2;
    listitem_t *li;
    ActNamespace *ns, *tmpns;

    if (OPT_EMPTY ($2)) {
      ns = $0->curns;
    }
    else {
      ns = ActNamespace::Global();
    }

    tmpns = ns;
    len = 0;
    while (tmpns->Parent()) {
      len = len + strlen (tmpns->Name()) + 1;
      tmpns = tmpns->Parent ();
    }

    len2 = len + 4;

    for (li = list_first ($3); li; li = list_next (li)) {
      s = (char *) list_value (li);
      len2 = len2 + strlen (s) + 1;
    }

    MALLOC (s, char, len2+2);
    s[0] = '"';
    s++;
    s[len] = '\0';

    /* there is stuff from the current namespace */
    if (len > 0) {
      tmpns = ns;
      while (tmpns->Parent ()) {
	s[len-1] = '/';
	len--;
	len2 = strlen (tmpns->Name ());
	strncpy (&s[len-len2], tmpns->Name(), len2);
	len -= len2;
      }
    }
    
    for (li = list_first ($3); li; li = list_next (li)) {
      strcat (s, (char *)list_value (li));
      if (list_next (li)) {
	strcat (s, "/");
      }
    }
    strcat (s, ".act\"");
    s--;

    apply_X_import_item_opt0 ($0, s);
    FREE (s);

    ns = apply_X_qualified_ns_opt0 ($0, $2, $3);

    if (!OPT_EMPTY ($4)) {
      /* done */
      ActRet *r;
      r = OPT_VALUE ($4);
      $A(r->type == R_STRING);
      apply_X_open_item_opt0 ($0, ns, r->u.str);
      FREE (r);
    }
    OPT_FREE ($4);
    return NULL;
}}
;

/*------------------------------------------------------------------------
 *
 *  open namespace ;
 *
 *  open namespace -> id ;
 *
 *------------------------------------------------------------------------
 */
open_item: "open" qualified_ns "->" ID  ";"
{{X:
    /* Open the namespace and rename it with the specified identifer */
    if (!$0->os->Open ($2, $4)) {
      $E("Cannot rename namespace `%s' as `::%s'---`::%s' already exists",
	 $2->Name(), $4, $4);
    }
    return NULL;
}}
| "open" qualified_ns ";"
{{X:
    /* Add the namespace to the search path, along with access
       permissions for types */
    if (!$0->os->Open ($2)) {
      $E("Failed to open namespace `%s'", $2->Name ());
    }
    return NULL;
}}
;


/*------------------------------------------------------------------------
 *
 *
 *  namespace foo { ... }
 *
 *
 *------------------------------------------------------------------------
 */
namespace_management: [ "export" ] "namespace" ID 
{{X:
    ActNamespace *ns;

    if ((ns = $0->curns->findNS ($3))) {
      if (OPT_EXISTS ($1)) {
	if (!ns->isExported()) {
	  $E("Inconsistent `export': all instances of the same namespace must either be\nexported, or not exported.");
	}
      }
      else if (ns->isExported()) {
	  $E("Inconsistent `export': all instances of the same namespace must either be\nexported, or not exported.");
      }
    }
    else {
      ns = new ActNamespace($0->curns, $3);
      if (OPT_EXISTS ($1)) {
	ns->MkExported ();
      }
    }
    $0->curns = ns;
    $0->scope = ns->CurScope ();
    OPT_FREE ($1);
}}
"{" [ ns_body ] "}"
{{X:
    $0->curns = $0->curns->Parent();
    OPT_FREE ($5);
    return NULL;
}}
;

/*
  qualified_ns is an optionally scoped root identifier that
  corresponds to the name of a namespace.
*/
qualified_ns[ActNamespace *]: [ "::" ] { ID "::" }*
{{X:
    listitem_t *li;
    ActNamespace *ns, *tmp;

    if (OPT_EXISTS ($1)) {
      ns = ActNamespace::Global();
    }
    else {
      ns = $0->curns;
    }
    OPT_FREE ($1);
    li = list_first ($2);
    $A(li);
    tmp = $0->os->find (ns, (char *)list_value (li));
    if (!tmp) {
      $E("Could not find namespace `%s' in `%s'", 
	 (char *) list_value (li), ns->Name());
    }
    ns = tmp;
    for (li = list_next (li); li; li = list_next (li)) {
      if (!(tmp = ns->findNS ((char *)list_value (li)))) {
	$E("Could not find namespace `%s' in `%s'", (char *)list_value (li),
	   ns->Name());
      }
      ns = tmp;
    }
    list_free ($2);
    return ns;
}}
;
#line 90 "act.m4"


/* types */
#line 1 "types.m4"
/*************************************************************************
 *
 *  Copyright (c) 2011 Rajit Manohar
 *  All Rights Reserved
 *
 **************************************************************************
 */


/**
 *************************************************************************
 *
 * Standard types in ACT
 *
 *************************************************************************
 */

/*------------------------------------------------------------------------
 *
 * A. Native types
 *
 *------------------------------------------------------------------------
 */
param_type[InstType *]: "pint"
{{X:
    return $0->tf->NewPInt();
}}
| "pints"
{{X:
    return $0->tf->NewPInts();
}}
| "pbool"
{{X:
    return $0->tf->NewPBool();
}}
| "preal"
{{X:
    return $0->tf->NewPReal();
}}
| "ptype" "<" physical_inst_type ">"
{{X:
    return $0->tf->NewPType($0->scope, $3);
}}
;

T_INT[int]: "int"
{{X: return 0; }}
| "ints"
{{X: return 1; }}
;

data_type[InstType *]: T_INT [ chan_dir ] [ "<" wint_expr ">" ]
{{X:
    ActRet *r;
    Type::direction d;
    Expr *width;

    if (OPT_EXISTS ($2)) {
      r = OPT_VALUE ($2);
      $A(r->type == R_DIR);
      d = r->u.dir;
      FREE (r);
    }
    else {
      d = Type::NONE;
    }
    OPT_FREE ($2);
    if (OPT_EXISTS ($3)) {
      r = OPT_VALUE ($3);
      $A(r->type == R_EXPR);
      width = r->u.exp;
      FREE (r);
    }
    else {
      width = const_expr (32);
    }
    OPT_FREE ($3);
    return $0->tf->NewInt ($0->scope, d, $1, width);
}}
| "bool" [ chan_dir ]
{{X:
    ActRet *r;
    Type::direction d;

    if (OPT_EXISTS ($2)) {
      r = OPT_VALUE ($2);
      $A(r->type == R_DIR);
      d = r->u.dir;
      FREE (r);
    }
    else {
      d = Type::NONE;
    }
    OPT_FREE ($2);
    return $0->tf->NewBool (d);
}}
| "enum" [ chan_dir ] "<" wint_expr ">"
{{X:
    ActRet *r;
    Type::direction d;

    if (OPT_EXISTS ($2)) {
      r = OPT_VALUE ($2);
      $A(r->type == R_DIR);
      d = r->u.dir;
      FREE (r);
    }
    else {
      d = Type::NONE;
    }
    OPT_FREE ($2);
    return $0->tf->NewEnum ($0->scope, d, $4);
}};

chan_type[InstType *]: "chan" [ chan_dir ] "(" { data_type "," }* ")"
{{X:
    ActRet *r;
    Type::direction d;
    listitem_t *li;
    int c = 0;
    InstType *ret;
    
    if (OPT_EXISTS ($2)) {
      r = OPT_VALUE ($2);
      $A(r->type == R_DIR);
      d = r->u.dir;
      FREE (r);
    }
    else {
      d = Type::NONE;
    }
    OPT_FREE ($2);
    for (li = list_first ($4); li; li = list_next (li)) {
      c++;
    }
    $A(c > 0);
    InstType **t;

    MALLOC (t, InstType *, c);

    c = 0;
    for (li = list_first ($4); li; li = list_next (li)) {
      t[c++] = (InstType *) list_value (li);
    }
    ret = $0->tf->NewChan ($0->scope, d, c, t);
    FREE (t);
    list_free ($4);
    return ret;
}}
;

chan_dir[Type::direction]: "?" 
{{X:
    return Type::IN;
}}
| "!" 
{{X:
    return Type::OUT;
}}
| "?!"
{{X:
    return Type::INOUT;
}}
| "!?"
{{X:
    return Type::OUTIN;
}}
;

/*------------------------------------------------------------------------
 *
 *  Physical type: data or channel. Not a parameter.
 *
 *------------------------------------------------------------------------
 */
physical_inst_type[InstType *]: data_type
{{X: return $1; }}
| chan_type 
{{X: return $1; }}
| user_type
{{X: return $1; }}
;


/*------------------------------------------------------------------------
 *
 *  Inst Type. This is any valid type (including templated types)
 *
 *------------------------------------------------------------------------
 */
inst_type[InstType *]: physical_inst_type
{{X: return $1; }}
| param_type 
{{X: return $1; }}
;


/*------------------------------------------------------------------------
 *
 *  User-defined type.
 *
 *------------------------------------------------------------------------
 */
user_type[InstType *]: qualified_type [ template_args ] [ chan_dir ]
{{X:
    InstType *ui;
    ActRet *r;
    listitem_t *li;
    list_t *l;
    UserDef *ud;

    ud = $1;
    $A(ud);

    ui = new InstType ($0->scope, ud);

    /* begin: set template parameters, if they exist */
    if (!OPT_EMPTY ($2)) {
      r = OPT_VALUE ($2);
      $A(r->type == R_LIST);
      l = r->u.l;
      FREE (r);
      if (ud->getNumParams() < list_length (l)) {
	$E("Number of template parameters specified (%d) > available parameters (%d) for %s", list_length (l), ud->getNumParams(), ud->getName());
      }
      
      int i = 0;

      ui->setNumParams (list_length (l));

      for (li = list_first (l); li; li = list_next (li)) {
	ui->setParam (i++, (AExpr *)list_value (li));
      }
      list_free (l);
    }
    OPT_FREE ($2);
    /* end: set template params */

    /* begin: set direction flags for type */
    Type::direction d;
    if (!OPT_EMPTY ($3)) {
      r = OPT_VALUE ($3);
      $A(r->type == R_DIR);
      d = r->u.dir;
      FREE (r);
    }
    else {
      d = Type::NONE;
    }
    OPT_FREE ($3);
    ui->SetDir (d);
    /* end: set dir flags */
    return $0->tf->NewUserDef ($0->scope, ui);
}}
;

template_args[list_t *]: "<" { array_expr "," }* ">"
{{X: return $2; }}
;


/* This is a qualified type name */
qualified_type[UserDef *]: [ "::" ] { ID "::" }*
{{X:
    ActNamespace *g, *ns;
    listitem_t *li;
    char *id;
    const char *gs;
    int export_perms = 1;
    UserDef *t;

    if (OPT_EMPTY ($1)) {
      g = $0->curns;
      gs = "";
    }
    else {
      g = ActNamespace::Global();
      gs = "::";
    }

    if (list_length ($2) > 1) {
      /* okay, we have to search through the namespaces */

      li = list_first ($2);
      id = (char *)list_value (li);
    
      /* find first component of namespace in search path */
      /* XXX: if there are multiple matches, we pick the first one. If
	 namespace foo can be found in multiple ways but only one of
	 them has bar as a sub-namespace, then:
	     foo:bar::baz
	 may fail even though there exists a way to match foo so that
	 it wouldn't fail.
      */
      ns = $0->os->find (g, id);
      if (!ns) {
	$e("Could not find specified type: %s", gs);
	print_ns_string ($f, $2);
	fprintf ($f, "\n");
	exit (1);
      }

      /* look for sub-namespaces */
      li = list_next (li);
      for (; list_next (li) != NULL; li = list_next (li)) {
	ns = ns->findNS ((char *)list_value (li));
	if (!ns) {
	  break;
	}
	export_perms = export_perms & (ns->isExported() ? 1 : 0);
	if (ns == $0->curns) {
	  export_perms = 1;
	}
      }
      if (!ns || !export_perms) {
	if (!ns) {
	  $e("Could not find specified type: %s", gs);
	}
	else {
	  $e("Type is not exported up the namespace hierarchy: %s", gs);
	}
	print_ns_string ($f, $2);
	fprintf ($f, "\n");
	exit (1);
      }
    }
    else {
      /* search through the open namespaces for this type */
      li = list_first ($2);

      ns = $0->os->findType (g, (char *)list_value (li));
      if (!ns) {
	$E("Could not find specified type: %s", (char *)list_value (li));
      }
      export_perms = 1;
    }
    /* 
       "li" is the list item corresponding to the type name
       "ns" is the namespace that should contain that type definition
    */
    id = (char *)list_value (li);
    t = ns->findType (id);
    if (!t || (ns != $0->curns && !t->IsExported())) {
      if (!t) {
	$e("Could not find specified type: %s", gs);
      }
      else {
	$e("Type is not exported up the namespace hierarchy: %s", gs);
      }
      print_ns_string ($f, $2);
      fprintf ($f, "\n");
      exit (1);
    }
    OPT_FREE ($1);
    list_free ($2);
    return t;
}}
;

/*
 * Array ranges
 */
dense_range[Array *]: dense_one_range dense_range
{{X:
    $1->Concat ($2);
    delete $2;
    return $1;
}}
| dense_one_range
{{X: return $1; }}
;

dense_one_range[Array *]: "[" wint_expr "]" 
{{X:
    Array *a = new Array ($2);
    return a;
}}
;

sparse_range[Array *]: sparse_one_range sparse_range
{{X:
    $1->Concat ($2);
    delete $2;
    return $1;
}}
| sparse_one_range
{{X:
    return $1;
}}
;

sparse_one_range[Array *]: "[" !noreal wint_expr [ ".." wint_expr ] "]"
{{X:
    Array *a;
    ActRet *r;
    
    if (OPT_EMPTY ($3)) {
      a = new Array ($2);
    }
    else {
      r = OPT_VALUE ($3);
      $A(r->type == R_EXPR);
      a = new Array ($2, r->u.exp);
      FREE (r);
    }
    OPT_FREE ($3);
    return a;
}}
;
#line 93 "act.m4"


/* definitions */
#line 1 "defs.m4"
/*************************************************************************
 *
 *  Copyright (c) 2011 Rajit Manohar
 *  All Rights Reserved
 *
 **************************************************************************
 */

/*------------------------------------------------------------------------
 *
 *   Grammar for definitions of processes, data, channels.
 *
 *------------------------------------------------------------------------
 */

definition: defproc_or_cell
| defdata
| defchan
| defenum
| deffunc
;

/*-- distinguish between a process and a cell --*/
def_or_proc[int]: "defproc" 
{{X:
    return 0;
}}
| "defcell"
{{X:
    return 1;
}}
;

/*
 * Templates
 */
template_spec: "export"
{{X:
    $A($0->u == NULL);
    $0->u = new UserDef ($0->curns);
    $0->u->MkExported();
}}
| [ "export" ] "template"
{{X:
    $A($0->u == NULL);
    $0->u = new UserDef ($0->curns);
    if (!OPT_EMPTY ($1)) {
      $0->u->MkExported();
    }
    $0->param_mode = 0;
    OPT_FREE ($1);
    $0->strict_checking = 1;
}}
"<" { param_inst ";" }* 
{{X:
    $0->param_mode = 1;
    list_free ($4);
}}
[ "|" { param_inst ";" }* ] ">"
{{X:
    if (!OPT_EMPTY ($5)) {
      list_t *m;
      ActRet *r;

      r = OPT_VALUE ($5);
      $A(r->type == R_LIST);
      m = r->u.l;
      FREE (r);
      list_free (m);
    }
    OPT_FREE ($5);
    return NULL;
}}
;

param_inst: param_type id_list
{{X:
    listitem_t *li;
    ActRet *r;
    InstType *it;

    for (li = list_first ($2); li; li = list_next (li)) {

      r = (ActRet *)list_value (li);
      $A(r->type == R_STRING);
      const char *id_name = r->u.str;
      FREE (r);

      li = list_next (li);

      r = (ActRet *)list_value (li);
      $A(r->type == R_LIST);
      list_t *m = r->u.l;
      FREE (r);

      it = $1;
      
      if (OPT_EMPTY (m)) {
	/* nothing needs to be done */
      }
      else {
	r = OPT_VALUE (m);
	$A(r->type == R_ARRAY);
	it->MkArray (r->u.array);
	FREE (r);
      }
      list_free (m);

      if ($0->u->AddMetaParam (it, id_name, $0->param_mode) != 1) {
	$E("Duplicate meta-parameter name in port list: `%s'", id_name);
      }
    }
    list_free ($2);
    return NULL;
}}
;

/*------------------------------------------------------------------------
 *  Identifier list with optional array
 *------------------------------------------------------------------------
 */
id_list[list_t *]: { ID [ dense_range ] "," }**
{{X: return $1; }}
;

/*------------------------------------------------------------------------
 *
 * Type signature for a process definition
 *
 *------------------------------------------------------------------------
 */
defproc_or_cell: [ template_spec ] 
{{X:
    if (OPT_EMPTY ($1)) {
      $0->u = new UserDef($0->curns);
    }
    else {
      $A($0->u);
    }
    OPT_FREE ($1);
    $0->strict_checking = 1;
}}
def_or_proc ID 
{{X:
    Process *p;
    UserDef *u;

    p = new Process ($0->u);
    delete $0->u;
    $0->u = NULL;
    
    if ($2) { 
      p->MkCell(); /* cell */
    }
    else {
      /* process */
    }

    switch ($0->curns->findName ($3)) {
    case 0:
      /* whew */
      break;
    case 1:
      $A(u = $0->curns->findType ($3));
      if (TypeFactory::isProcessType(u)) {
	/* there is hope */
      }
      else {
	$E("Name `%s' already used as a previous type definition", $3);
      }
      break;
    case 2:
      $E("Name `%s' already used as a namespace", $3);
      break;
    case 3:
      $E("Name `%s' already used as an instance", $3);
      break;
    default:
      $E("Should not be here ");
      break;
    }
    $0->u_p = p;
    /*printf ("Orig scope: %x\n", $0->scope);*/
    $0->scope = $0->u_p->CurScope ();
}}
[ "(" port_formal_list ")" ] 
{{X:
    /* Create type here */
    UserDef *u;

    if (u = $0->curns->findType ($3)) {
      /* check if the type signature is identical */
      if (u->isEqual ($0->u_p)) {
	delete $0->u_p;
	$0->u_p = dynamic_cast<Process *>(u);
	$A($0->u_p);
      }
      else {
	$E("Name `%s' previously defined as a different process", $3);
      }
    }
    else {
      $A($0->curns->CreateType ($3, $0->u_p));
    }
    OPT_FREE ($4);
    $0->scope = $0->u_p->CurScope ();
    $0->strict_checking = 0;
}}
proc_body
{{X:
    $0->u_p = NULL;
    $0->scope = $0->curns->CurScope();
    return NULL;
}}
;

proc_body: ";"
{{X:
    return NULL;
}}
| "{" def_body  "}"
{{X:
    if ($0->u_p->isDefined()) {
      $E("Process `%s': duplicate definition with the same type signature", $0->u_p->getName());
    }
    $0->u_p->MkDefined ();
    return NULL;
}}
;

port_formal_list: { single_port_item ";" }*
{{X:
    /* handled in single_port_item */
    list_free ($1);
    return NULL;
}}
;

single_port_item: [ "+" ] /* override */  physical_inst_type id_list
{{X:
    listitem_t *li;
    ActRet *r;
    InstType *it;
    UserDef *u;
    int is_override;

    if (OPT_EMPTY ($1)) {
      is_override = 0;
    }
    else {
      is_override = 1;
    }
    OPT_FREE ($1);

    /* Make sure that port types are acceptable */
    if ($0->u_p) {
      /* We are currently processing a defproc port list */
      u = $0->u_p;
      if (TypeFactory::isProcessType ($2->BaseType())) {
	r = (ActRet *) list_value (list_first ($3));
	$A(r->type == R_STRING);
	$E("Parameter `%s': port parameter for a process cannot be a process", r->u.str);
      }
    }
    else if ($0->u_d) {
      /* This is a user-defined data type */
      u = $0->u_d;
      const char *err = NULL;

      if (TypeFactory::isProcessType ($2->BaseType())) {
	err = "process";
      }
      else if (TypeFactory::isChanType ($2->BaseType())) {
	err = "channel";
      }
      if (err) {
	r = (ActRet *) list_value (list_first ($3));
	$A(r->type == R_STRING);
	$E("Parameter `%s': port parameter for a data-type cannot be a %s",
	   r->u.str, err);
      }
    }
    else if ($0->u_c) {
      /* This is a user-defined channel type */
      u = $0->u_c;
      if (TypeFactory::isProcessType ($2->BaseType())) {
	r = (ActRet *) list_value (list_first ($3));
	$A(r->type == R_STRING);
	$E("Parameter `%s': port parameter for a channel cannot be a process", r->u.str);
      }
    }
    else {
      /* should not be here */
      $A(0);
    }

    /* Walk through identifiers */
    for (li = list_first ($3); li; li = list_next (li)) {
      r = (ActRet *) list_value (li);
      $A(r->type == R_STRING);
      const char *id_name = r->u.str;
      FREE (r);

      li = list_next (li);

      r = (ActRet *) list_value (li);
      $A(r->type == R_LIST);
      list_t *m = r->u.l;
      FREE (r);

      if (OPT_EMPTY (m)) {
	/* nothing---use the base insttype directly */
	it = $2;
      }
      else {
	/* we need to replicate the insttype */
	it = new InstType ($2);
	r = OPT_VALUE (m);
	$A(r->type == R_ARRAY);
	r->u.array->mkArray ();
	it->MkArray (r->u.array);
	it->MkCached ();
	FREE (r);
      }
      list_free (m);

      if (u->AddPort (it, id_name) != 1) {
	/* XXX: migt be an override */
	if (is_override) {
	  $W("Could be an override, so fix it!\n");
	}
	$E("Duplicate parameter name in port list: `%s'", id_name);
      }
      else {
	if (is_override) {
	  $E("Override specified, but parameter `%s' does not exist!", 
	     id_name);
	}
      }
    }
    list_free ($3);
    return NULL;
}}
;

/*------------------------------------------------------------------------
 *
 *  Data type definition (deftype)
 *
 *------------------------------------------------------------------------
 */
defdata: [ template_spec ]
{{X:
    if (OPT_EMPTY ($1)) {
      $0->u = new UserDef ($0->curns);
    }
    else {
      $A($0->u);
    }
    OPT_FREE ($1);
    $0->strict_checking = 1;
}}
"deftype" ID 
{{X:
    Data *d;
    UserDef *u;

    d = new Data ($0->u);
    delete $0->u;
    $0->u = NULL;

    switch ($0->curns->findName ($3)) {
    case 0:
      break;
    case 1:
      $A(u = $0->curns->findType ($3));
      if (TypeFactory::isDataType (u)) {
	Data *td = dynamic_cast<Data *>(u);
	$A(td);
	if (td->isEnum()) {
	  $E("Name `%s' already used in as an enumeration data type", $3);
	}
	/* now there is hope */
      }
      else {
	$E("Name `%s' already used in a previous type definition", $3);
      }
      break;
    case 2:
      $E("Name `%s' already used as a namespace", $3);
      break;
    case 3:
      $E("Name `%s' already used as an instance", $3);
      break;
    default:
      $E("Should not be here ");
      break;
    }
    $0->u_d = d;
    $0->scope = d->CurScope ();
}}
is_a physical_inst_type
{{X:
    /* parent type cannot be
       - process
       - channel
       
       Note that meta-params are ruled out by parser rules 
    */
    if (TypeFactory::isProcessType ($5->BaseType())) {
      $E("A data type cannot be related to a process");
    }
    if (TypeFactory::isChanType ($5->BaseType())) {
      $E("A data type cannot be related to a channel");
    }
    if (TypeFactory::isUserType ($5->BaseType ())) {
      $0->scope->Merge (dynamic_cast<UserDef *>($5->BaseType ())->CurScope ());
    }
    $0->u_d->SetParent ($5, $4);
}}
[ "("  port_formal_list ")" ] 
{{X:
    UserDef *u;

    if (u = $0->curns->findType ($3)) {
      if (u->isEqual ($0->u_d)) {
	delete $0->u_d;
	$0->u_d = dynamic_cast<Data *>(u);
	$A($0->u_d);
      }
      else {
	$E("Name `%s' previously defined as a different data type", $3);
      }
    }
    else {
      $A($0->curns->CreateType ($3, $0->u_d));
    }
    OPT_FREE ($6);
    $0->strict_checking = 0;
}}
data_body
{{X:
    /* XXX: body of data type */
    $0->u_d = NULL;
    $0->scope = $0->curns->CurScope ();
    return NULL;
}}
;

is_a[int]: "<:" 
{{X:
    return 0;
}}
| "="
{{X:
    return 1;
}}
;

data_body: ";"
	   /* empty */
{{X: return NULL; }}
| "{" base_body [ methods_body ] "}"
{{X:
    ActRet *r;

    $A($0->u_d);
    if ($0->u_d->isDefined ()) {
      $E("Data definition `%s': duplicate definition with the same type signature", $0->u_d->getName ());
    }
    $0->u_d->MkDefined();

    $0->u_d->setBody ($2);
    OPT_FREE ($3);
    return NULL;
}}
;

methods_body: "methods" "{" [ method_list ] "}"
{{X:
    OPT_FREE ($3);
    return NULL;
}}
;

method_list: one_method method_list 
| one_method
;

one_method: ID "{" hse_body "}"
{{X:
    if ($0->u_d) {
      /* data methods */
      if (strcmp ($1, "set") == 0) {
	if ($0->u_d->getMethodset()) {
	  $E("Duplicate `set' method");
	}
	$0->u_d->setMethodset ($3);
      }
      else if (strcmp ($1, "get") == 0) {
	if ($0->u_d->getMethodget()) {
	  $E("Duplicate `get' method");
	}
	$0->u_d->setMethodget ($3);
      }
      else {
	$E("Method `%s' is not supported", $1);
      }
    }
    else if ($0->u_c) {
      /* channel methods */
      if (strcmp ($1, "send") == 0) {
	if ($0->u_c->getMethodsend()) {
	  $E("Duplicate `send' method");
	}
	$0->u_c->setMethodsend ($3);
      }
      else if (strcmp ($1, "recv") == 0) {
	if ($0->u_c->getMethodrecv()) {
	  $E("Duplicate `recv' method");
	}
	$0->u_c->setMethodrecv ($3);
      }
      else {
	$E("Method `%s' is not supported", $1);
      }
    }
    else {
      $E("Methods body in unknown context?");
    }
    return NULL;
}}
;

/*
  For both channel and data types you can have spec bodies and aliases
*/
base_body[ActBody *]: lang_spec base_body
{{X:
    if ($1) {
      $1->Append ($2);
      return $1;
    }
    else {
      return $2;
    }
}}
| alias base_body
{{X:
    if ($1) {
      $1->Append ($2);
      return $1;
    }
    else {
      return $2;
    }
}}
| /* empty */
;

/*------------------------------------------------------------------------
 *
 *  User-defined channel definition. "defchan"
 *
 *------------------------------------------------------------------------
 */
defchan: [ template_spec ]
{{X:
    if (OPT_EMPTY ($1)) {
      $0->u = new UserDef($0->curns);
    }
    else {
      $A($0->u);
    }
    OPT_FREE ($1);
    $0->strict_checking = 1;
}}
"defchan" ID 
{{X:
    Channel *c;
    UserDef *u;

    c = new Channel ($0->u);
    delete $0->u;
    $0->u = NULL;

    switch ($0->curns->findName ($3)) {
    case 0:
      /* good */
      break;
    case 1:
      $A(u = $0->curns->findType ($3));
      if (TypeFactory::isChanType (u)) {
	/* there is hope */
      }
      else {
	$E("Name `%s' already used in a previous type definition", $3);
      }
      break;
    case 2:
      $E("Name `%s' already used as a namespace", $3);
      break;
    case 3:
      $E("Name `%s' already used as an instance", $3);
      break;
    default:
      $E("Should not be here ");
      break;
    }
    $0->u_c = c;
    $0->scope = $0->u_c->CurScope ();
}}
is_a physical_inst_type
{{X:
    if (TypeFactory::isProcessType ($5->BaseType())) {
      $E("A channel type cannot be related to a process");
    }
    if (TypeFactory::isDataType ($5->BaseType())) {
      $E("A channel type cannot be related to a data type");
    }
    if (TypeFactory::isUserType ($5->BaseType ())) {
      $0->scope->Merge (dynamic_cast<UserDef *>($5->BaseType ())->CurScope ());
    }
    $0->u_c->SetParent ($5, $4);
}}
 [ "(" port_formal_list ")" ] 
{{X:
    UserDef *u;

    if (u = $0->curns->findType ($3)) {
      if (u->isEqual ($0->u_c)) {
	delete $0->u_c;
	$0->u_c = dynamic_cast<Channel *>(u);
	$A($0->u_c);
      }
      else {
	$E("Name `%s' previously defined as a different channel", $3);
      }
    }
    else {
      $A($0->curns->CreateType ($3, $0->u_c));
    }
    list_free ($6);
    $0->strict_checking = 0;
}}
chan_body
{{X:
    $0->u_c = NULL;
    $0->scope = $0->curns->CurScope ();
    return NULL;
}}
;

chan_body: ";" | "{" base_body [ methods_body ] "}"
{{X:
    $A($0->u_c);
    if ($0->u_c->isDefined ()) {
      $E("Channel definition `%s': duplicate definition with the same type signature", $0->u_c->getName ());
    }
    $0->u_c->MkDefined ();

    $0->u_c->setBody ($2);
    OPT_FREE ($3);
    return NULL;
}}
;


/*------------------------------------------------------------------------
 *
 * Enumerations
 *
 *------------------------------------------------------------------------
 */
defenum: "defenum" ID
{{X:
    Data *d;
    UserDef *u;

    switch ($0->curns->findName ($2)) {
    case 0:
      /* good */
      break;
    case 1:
      $A(u = $0->curns->findType ($2));
      if (TypeFactory::isDataType (u)) {
	Data *td = dynamic_cast<Data *>(u);
	$A(td);
	if (!td->isEnum()) {
	  $E("Name `%s'already used as a non-enumeration data type", $2);
	}
      }
      else {
	$E("Name `%s' already used in a previous type definition", $2);
      }
      break;
    case 2:
      $E("Name `%s' already used as a namespace", $2);
      break;
    case 3:
      $E("Name `%s' already used as an instance", $2);
      break;
    default:
      $E("Should not be here ");
      break;
    }

    u = new UserDef($0->curns);
    d = new Data (u);
    delete u;
    $0->u_d = d;
}}
enum_body
{{X:
    UserDef *u;

    if ((u = $0->curns->findType ($2))) {
      if (u->isDefined() && ($3 == 1)) {
	$E("enum `%s': duplicate definition", $2);
      }
      if (!u->isDefined() && ($3 == 1)) {
	u->MkCopy ($0->u_d);
	u->MkDefined();
      }
      delete $0->u_d;
    }
    else {
      $A($0->curns->CreateType ($2, $0->u_d));
    }
    $0->u_d = NULL;
    $0->scope = $0->curns->CurScope ();
    return NULL;
}};

enum_body[int]: ";" 
{{X:
    /* nothing to do here other than marking this as an enumeration */
    $0->u_d->MkEnum();
    return 0;
}}
| "{" bare_id_list "}" ";"
{{X:
    listitem_t *li;

    for (li = list_first ($2); li; li = list_next (li)) {
      const char *s = (char *)list_value (li);
      $0->u_d->AddMetaParam (NULL, s);
    }
    list_free ($2);
    return 1;
}}
;

bare_id_list[list_t *]: { ID "," }*
{{X:
    return $1;
}}
;


/*------------------------------------------------------------------------
 *
 * Functions: XXX fixme
 *
 *------------------------------------------------------------------------
 */
deffunc: "function" ID "(" { param_inst ";" }* ")" ":" param_type 
func_body
;

func_body: ";" | "{" "}" ;


/*------------------------------------------------------------------------
 *
 * Core ACT language: body of process defintions
 *
 *------------------------------------------------------------------------
 */
def_body: base_item_list 
{{X:
    $0->u_p->setBody ($1);
    return NULL;
}}
| /* nothing */;


base_item_list[ActBody *]: base_item base_item_list 
{{X:
    if ($1) {
      $1->Append ($2);
      return $1;
    }
    else {
      return $2;
    }
}}
| base_item
{{X:
    return $1;
}}
;

base_item[ActBody *]: instance 
{{X: return $1; }}
| connection 
{{X: return $1; }}
| alias 
{{X: return $1; }}
| language_body
{{X: return $1; }}
| loop 
{{X: return $1; }}
| conditional
{{X: return $1; }};


instance[ActBody *]: [ "+" ] inst_type
{{X:
    if (!OPT_EMPTY ($1)) {
      $0->override = 1;
    }
    else {
      $0->override = 0;
    }
    OPT_FREE ($1);
    $0->t = $2;
}}
{ instance_id "," }* ";" 
{{X:
    listitem_t *li;
    ActBody *ret, *cur, *tl;

    /* Don't delete any TypeFactory cached instance types */
    if ($0->t->isTemp()) {
      delete $0->t;
    }
    $0->t = NULL;

    /* reserve a slot for this in the type table. the work is done in
       the instance_id thing */

    cur = NULL;
    ret = NULL;
    tl = NULL;

    for (li = list_first ($3); li; li = list_next (li)) {
      cur = (ActBody *)list_value (li);
      if (!cur) continue;

      if (!ret) {
	ret = cur;
	tl = ret->Tail ();
      }
      else {
	tl->Append (cur);
	tl = tl->Tail ();
      }
    }
    list_free ($3);
    return ret;
}}
;

special_connection_id[ActBody *]: ID [ dense_range ] 
{{X:
    $0->i_id = $1;
    $0->i_t = $0->scope->Lookup ($1);
    if (!$0->i_t) {
      $E("Identifier `%s' not found in current scope", $1);
    }
    $0->t_inst = NULL;
    if (!OPT_EMPTY ($2)) {
      ActRet *r;

      r = OPT_VALUE ($2);
      $A(r->type == R_ARRAY);
      $0->a_id = new ActId ($1, r->u.array);
      FREE (r);
    }
    else {
      $0->a_id = NULL;
    }
    OPT_FREE ($2);
}}
"(" port_conn_spec ")" [ "@" attr_list ]
{{X:
    ActBody *b;
    /* connections handled already */
    if (!OPT_EMPTY ($6)) {
      /* XXX: handle attributes, if any */
    }
    OPT_FREE ($6);
    $0->a_id = NULL;
    b = $0->t_inst;
    $0->t_inst = NULL;
    return b;
}}
| ID [ dense_range ] "@" attr_list
{{X:
    /* XXX: attributes */
    return NULL;
}}
;

instance_id[ActBody *]: ID [ sparse_range ] 
{{X:
    InstType *it;
    ActRet *r;

    if ($0->override) {
      /* XXX: IT IS AN OVERRIDE */
      $W("Override, figure out what to do!\n");
    }

    $0->i_t = NULL;
    $0->i_id = $1;

    $A($0->t);

    /* Create the instance */
    $0->i_t = $0->t;

    if (!OPT_EMPTY ($2)) {
      $A($0->t->arrayInfo() == NULL);
	
      r = OPT_VALUE ($2);
      $A(r->type == R_ARRAY);

      it = new InstType ($0->t);
      r->u.array->mkArray ();
      it->MkArray (r->u.array);
      FREE (r);
    }
    else {
      it = $0->t;
      /*
      if ($0->t->isTemp()) {
	it = new InstType ($0->t);
      }
      else {
	it = $0->t;
      }
      */
    }

    $A($0->scope);
      
    /*printf ("scope: %x\n", $0->scope);*/

    InstType *prev_it;

    if (prev_it = $0->scope->Lookup ($1)) {
      if (OPT_EMPTY ($2)) {
	/* not an array instance */

	/* XXX: what happens if I say 
	   [ .. -> bool a; [] ... -> bool a; ]
	   Right now  the program will complain. Is that okay, or
	   should we punt? We could put in a check to see if the two
	   might be exclusive, and then check again at instantiation
	   time. 

	   Check if conditional, and ignore it.
	*/
	$E("Duplicate instance for name `%s'", $1);
      }
      else {
	/* check weak compatibility of instance types, since this
	   could be a sparse array */
	if (!prev_it->isEqual (it, 1)) {
	  $e("Array instance for `%s' is incompatible with previous instance of the same name", $1);
	  fprintf ($f, "\n prev: ");
	  prev_it->Print ($f);
	  fprintf ($f, "\n here: ");
	  it->Print ($f);
	  fprintf ($f, "\n");
	  exit (1);
	}
	/* Type is fine; check if we are a port! If so, we have a
	   problem. To do this, we have to check if this instance_id
	   is within a UserDef or not. 
	*/
	if ($0->u_p) {
	  if ($0->u_p->FindPort ($1) != 0) {
	    $E("Array instance for `%s': cannot extend a port array", $1);
	  }
	}
      }
    }
    else {
      /* create a slot */
      if (it->arrayInfo()) {
	/* force it to be an array, and not a de-reference */
	it->arrayInfo()->mkArray ();
      }
      it = $0->tf->NewUserDef ($0->scope, it);
      $A($0->scope->Add ($1, it));
    }
    $0->t_inst = new ActBody_Inst (it, $1);
}}
[ "(" port_conn_spec ")" ] [ "@" attr_list ] opt_extra_conn 
{{X:
    ActBody *b = NULL;
    ActRet *r;

    /* Handle attributes, if any */
    if (!OPT_EMPTY ($4)) {
      /* XXX: ignoring attributes at the moment */
      /* XXX: add attributes to this instance */

      /* free attribute list
	 An attribute list is a list of wrapped (string, expr)s
      */
      r = OPT_VALUE ($4);
      $A(r->type == R_ATTR);
      FREE (r);
      OPT_FREE ($4);
    }

    /* XXX: Process connections */

    /* 1: Connections in the port conn spec are
       processed in port_conn_spec itself
    */
    OPT_FREE ($3);

    b = $0->t_inst;
    $0->t_inst = NULL;

    /* 2: Connections on the RHS */
    if ($5) {
      listitem_t *li;
      ActBody *tmp;
      
      if (!OPT_EMPTY ($2)) {
	$E("Connection can only be specified for non-array instances");
      }

      if (b) {
	tmp = b->Tail ();
      }
      else {
	tmp = NULL;
      }

      /*printf ("Length: %d\n", list_length ($5));*/

      for (li = list_first ($5); li; li = list_next (li)) {
	ActId *a = new ActId ($1);
	AExpr *ae;
	ActRet *ar;

	/*printf ("chk: "); a->Print (stdout); printf ("\n"); fflush (stdout);*/

	ar = (ActRet *)list_value (li);
	$A(ar);
	$A(ar->type == R_AEXPR);

	ae = ar->u.ae;
	FREE (ar);

	/*printf ("Got: %x\n", ae);

	printf ("Connect: ");
	a->Print (stdout);
	printf (" to: ");
	ae->Print (stdout);
	printf ("\n");*/

	type_set_position ($l, $c, $n);
	if (!act_type_conn ($0->scope, a, ae)) {
	  $e("Typechecking failed on connection!");
	  fprintf ($f, "\n\t%s\n", act_type_errmsg ());
	  exit (1);
	}

	if (!tmp) {
	  tmp = new ActBody_Conn (a, ae);
	}
	else {
	  tmp->Tail()->Append (new ActBody_Conn (a, ae));
	  tmp = tmp->Tail ();
	}
      }
      list_free ($5);
    }
    OPT_FREE ($2);
    return b;
}}
;

opt_extra_conn[list_t *]: [ "=" { array_expr "=" }** ]
{{X:
    list_t *l;

    if (OPT_EMPTY ($1)) {
      OPT_FREE ($1);
      l = NULL;
    }
    else {
      ActRet *r;

      r = OPT_VALUE ($1);

      $A(r->type == R_LIST);

      l = r->u.l;
      FREE (r);
      OPT_FREE ($1);
    }
    return l;
}}
;

/* the "CONNECT" body statements are returned in t_inst */
port_conn_spec: { opt_array_expr "," }*
{{X:
    int pos = 0;
    listitem_t *li;
    AExpr *ae;
    UserDef *ud;
    ActBody *b, *ret;

    $A($0->i_t);
    $A($0->i_id);
    
    ud = dynamic_cast<UserDef *>($0->i_t->BaseType());
    if (!ud) {
      $E("Connection specifier used for instance `%s' whose root type is `%s'\n\t(not a user-defined type)", $0->i_id, $0->i_t->BaseType()->getName());
    }

    b = NULL;
    ret = NULL;

    /* If the ID is an array type, there had better be a deref; in
       this case, a_id is set with the appropriate ActId */
    if ($0->i_t->arrayInfo ()) {
      if (!$0->a_id) {
	$E("Connection specifier for an array instance `%s'", $0->i_id);
      }
      else {
	$A($0->a_id->arrayInfo ());
	if ($0->a_id->arrayInfo()->nDims() !=
	    $0->i_t->arrayInfo()->nDims()) {
	  $E("Array de-reference for `%s': mismatch in dimensions (%d v/s %d)", $0->i_id, $0->i_t->arrayInfo()->nDims (), $0->a_id->arrayInfo()->nDims());
	}
      }
    }

    for (li = list_first ($1); li; li = list_next (li)) {
      if (pos > ud->getNumPorts()) {
	$E("Too many ports specified in connection specifier.\n\tType `%s' only has %d ports!", ud->getName(), ud->getNumPorts());
      }
      ae = (AExpr *) list_value (li);
      if (ae) {
	const char *pn = ud->getPortName (pos);
	ActId *id;
	ActBody *tmp;

	if ($0->a_id) {
	  /* array deref */
	  id = $0->a_id->Clone ();
	}
	else {
	  id = new ActId ($0->i_id, NULL);
	}
	id->Append (new ActId (pn, NULL));

	type_set_position ($l, $c, $n);
	if (!act_type_conn ($0->scope, id, ae)) {
	  $e("Typechecking failed on connection!");
	  fprintf ($f, "\n\t%s\n", act_type_errmsg ());
	  exit (1);
	}
	tmp = new ActBody_Conn (id, ae);
	if (!b) {
	  b = tmp;
	  ret = b;
	}
	else {
	  b->Append (tmp);
	  b = b->Tail ();
	}
      }
      pos++;
    }
    list_free ($1);
    if ($0->t_inst) {
      $0->t_inst->Tail()->Append (ret);
    }
    else {
      $0->t_inst = ret;
    }
    if ($0->a_id) {
      delete $0->a_id;
    }
    $0->a_id = NULL;
    return NULL;
}}
| { "." ID "=" array_expr "," }**
{{X:
    UserDef *ud;
    ActBody *b, *tmp, *ret;
    ActRet *r;
    listitem_t *li;
    const char *str;
    AExpr *ae;
    int i;
    
    $A($0->i_t);
    $A($0->i_id);
    
    ud = dynamic_cast<UserDef *>($0->i_t->BaseType());

    if (!ud) {
      $E("Connection specifier used for instance `%s' whose root type is `%s'\n\tnot a user-defined type", $0->i_id, ud->getName());
    }

    b = NULL;
    ret = NULL;

    for (li = list_first ($1); li; li = list_next (li)) {
      r = (ActRet *)list_value (li);
      $A(r->type == R_STRING);
      str = r->u.str;
      FREE (r);

      li = list_next (li);
      $A(li);
      r = (ActRet *)list_value (li);
      $A(r->type == R_AEXPR);
      ae = r->u.ae;
      FREE (r);
      
      for (i=ud->getNumPorts()-1; i >= 0; i--) {
	if (strcmp (str, ud->getPortName (i)) == 0) {
	  break;
	}
      }
      if (i < 0) {
	$E("`%s' is not a valid port name for type `%s'", str, 
	   ud->getName ());
      }
      ActId *id  = new ActId ($0->i_id, NULL);
      id->Append (new ActId (str, NULL));
      type_set_position ($l, $c, $n);
      if (!act_type_conn ($0->scope, id, ae)) {
	$e("Typechecking failed on connection!");
	fprintf ($f, "\n\t%s\n", act_type_errmsg ());
	exit (1);
      }
      tmp = new ActBody_Conn (id, ae);
      if (!b) {
	b = tmp;
	ret = b;
      }
      else {
	b->Append (tmp);
	b = b->Tail ();
      }
    }
    list_free ($1);
    if ($0->t_inst) {
      $0->t_inst->Tail()->Append (ret);
    }
    else {
      $0->t_inst = ret;
    }
    return NULL;
}}
;

alias[ActBody *]: array_expr "=" { array_expr "=" }* ";"
{{X:
    ActBody *b, *tmp, *ret;
    listitem_t *li;
    AExpr *ae;

    b = NULL;
    ret = NULL;

    for (li = list_first ($3); li; li = list_next (li)) {
      ae = (AExpr *) list_value (li);
      type_set_position ($l, $c, $n);
      if (!act_type_conn ($0->scope, $1, ae)) {
	$e("Typechecking failed on connection!");
	fprintf ($f, "\n\t%s\n", act_type_errmsg ());
	exit (1);
      }
      if (li == list_first ($3)) {
	tmp = new ActBody_Conn ($1, ae);
      }
      else {
	tmp = new ActBody_Conn ($1->Clone(), ae);
      }
      if (!b) {
	b = tmp;
	ret = b;
      }
      else {
	b->Append (tmp);
	b = b->Tail ();
      }
    }
    list_free ($3);
    return ret;
}}
;

connection[ActBody *]: special_connection_id ";"
{{X: return $1; }}
;

loop[ActBody *]: "(" ";" ID 
{{X:
    if ($0->scope->Lookup ($3)) {
      $E("Identifier %s already defined in current scope", $3);
    }
    $0->scope->Add ($3, $0->tf->NewPInt());
}}
":" !noreal wint_expr [ ".." wint_expr ] ":" 
   base_item_list ")"
{{X:
    if (OPT_EMPTY ($6)) {
      $0->scope->Del ($3);
      return new ActBody_Loop (ActBody_Loop::SEMI, $3, NULL, $5, $8);
    }
    else {
      ActRet *r;
      r = OPT_VALUE ($6);
      OPT_FREE ($6);
      $A(r->type == R_EXPR);
      $0->scope->Del ($3);
      return new ActBody_Loop (ActBody_Loop::SEMI, $3, $5, r->u.exp, $8);
    }
}}
;

conditional[ActBody *]: "[" guarded_cmds "]"
{{X:
    return $2; 
}}
;

guarded_cmds[ActBody *]: { gc_1 "[]" }*
{{X:
    listitem_t *li;
    ActBody_Select_gc *ret, *prev, *stmp;

    ret = NULL;
    for (li = list_first ($1); li; li = list_next (li)) {
      stmp = (ActBody_Select_gc *) list_value (li);
      if (!ret) {
	ret = stmp;
	prev = stmp;
      }
      else {
	prev->Append (stmp);
	prev = stmp;
      }
    }
    return new ActBody_Select (ret);
}}
;

gc_1[ActBody_Select_gc *]: wbool_expr "->" base_item_list
{{X:
    return new ActBody_Select_gc ($1, $3);
}}
| "else" "->" base_item_list
{{X:
    return new ActBody_Select_gc (NULL, $3);
}}
;
#line 96 "act.m4"


/* languages */
#line 1 "lang.m4"
/*************************************************************************
 *
 *  Copyright (c) 2011 Rajit Manohar
 *  All Rights Reserved
 *
 **************************************************************************
 */

/* 
   Language bodies
*/

language_body[ActBody *]: lang_chp 
| lang_hse 
| lang_prs 
{{X:
    return $1;
}}
| lang_spec 
| lang_size ;

supply_spec: "<" bool_expr_id [ "," bool_expr_id ]
                 [ "|" bool_expr_id "," bool_expr_id ] 
             ">"
{{X:
    ActRet *r;

    $0->supply.vdd = $2;
    if (!OPT_EMPTY ($3)) {
      r = OPT_VALUE ($3);
      $A(r->type == R_ID);
      $0->supply.gnd = r->u.id;
      FREE (r);
    }
    else {
      $0->supply.gnd = NULL;
    }
    OPT_FREE ($3);

    if (!OPT_EMPTY ($4)) {
      r = OPT_VALUE ($4);
      $A(r->type == R_ID);
      $0->supply.psc = r->u.id;
      FREE (r);
      r = OPT_VALUE2 ($4);
      $A(r->type == R_ID);
      $0->supply.nsc = r->u.id;
      FREE (r);
    }
    else {
      $0->supply.psc = NULL;
      $0->supply.nsc = NULL;
    }
    OPT_FREE ($4);
    return NULL;
}}
;

lang_chp: "chp" [ supply_spec ] "{" [ chp_body ] "}"
{{X:
    $0->supply.vdd = NULL;
    $0->supply.gnd = NULL;
    $0->supply.psc = NULL;
    $0->supply.nsc = NULL;
    OPT_FREE ($2);
    return NULL;
}}
;

lang_hse: "hse" [ supply_spec ] "{" [ hse_body ] "}" 
{{X:
    $0->supply.vdd = NULL;
    $0->supply.gnd = NULL;
    $0->supply.psc = NULL;
    $0->supply.nsc = NULL;
    OPT_FREE ($2);
    return NULL;
}}
;

lang_prs[ActBody *]: "prs" [ supply_spec ] "{" [ prs_body ] "}" 
{{X:
    ActBody *b;
    act_prs *p;

    b = NULL;
    p = NULL;
    if (!OPT_EMPTY ($4)) {
      ActRet *r;

      r = OPT_VALUE ($4);
      $A(r->type == R_PRS_LANG);
      NEW (p, act_prs);
      p->p = r->u.prs;
      FREE (r);
      p->vdd = $0->supply.vdd;
      p->gnd = $0->supply.gnd;
      p->nsc = $0->supply.nsc;
      p->psc = $0->supply.psc;
    }
    if (p) {
      b = new ActBody_Lang (p);
    }
    $0->supply.vdd = NULL;
    $0->supply.gnd = NULL;
    $0->supply.psc = NULL;
    $0->supply.nsc = NULL;
    OPT_FREE ($2);
    return b;
}}
;

lang_spec[ActBody *]: "spec" "{" [ spec_body ] "}"
;

chp_body: { chp_comma_list ";" }*
;

chp_comma_list: { chp_body_item "," }*
;

chp_body_item: base_stmt
| select_stmt
| loop_stmt
;

base_stmt: send_stmt
    | recv_stmt
    | assign_stmt
    | "skip" 
    | "(" chp_body ")"
    | ID "(" { chp_log_item "," }* ")" /* log */
;


chp_log_item: expr_id
|  STRING
;

send_stmt: expr_id "!" send_data
;

send_data: w_expr 
| "(" { w_expr "," }* ")" 
;

recv_stmt: expr_id "?" recv_id
;

recv_id: expr_id
| "(" { expr_id "," }** ")" 
;

assign_stmt: expr_id ":=" w_expr
| expr_id dir
;

select_stmt: "[" { guarded_cmd "[]" }* "]"
| "[" wbool_expr "]" 
;


guarded_cmd: wbool_expr "->" chp_body 
| "else" "->" chp_body
;

loop_stmt: "*[" chp_body "]"
| "*[" { guarded_cmd "[]" }* "]"
;

hse_body[ActBody *]: { hse_body_item ";" }*
;

hse_body_item: { hse_assign_stmt "," }* 
| hse_loop_stmt
| hse_select_stmt
| "skip"
| "(" hse_body ")"
;

hse_assign_stmt: expr_id dir 
;

hse_select_stmt: "[" { hse_guarded_cmd "[]" }* "]"
| "[" wbool_expr "]" 
;

hse_guarded_cmd: wbool_expr "->" hse_body
| "else" "->" hse_body
;

hse_loop_stmt: "*[" hse_body "]"
| "*[" { hse_guarded_cmd "[]" }* "]"
;

prs_body[act_prs_lang_t *]: [ attr_list ] 
{{X:
    $0->line = $l;
    $0->column = $c;
    $0->file = $n;
}}
single_prs prs_body
{{X:
    $2->next=  $3;
    return $2;
}}
| [ attr_list ] 
{{X:
    $0->line = $l;
    $0->column = $c;
    $0->file = $n;
}}
single_prs
{{X:
    return $2;
}}
;

attr_list[act_attr_t *]: "[" { ID "=" w_expr ";" }** "]"
{{X: 
    listitem_t *li;
    act_attr_t *a, *ret, *prev;
    ActRet *r;

    a = ret = prev = NULL;
    for (li = list_first ($2); li; li = list_next (li)) {
      r = (ActRet *)list_value (li);
      $A(r);
      $A(r->type == R_STRING);
      if (!ret) {
	NEW (ret, act_attr_t);
	a = ret;
      }
      else {
	NEW (a, act_attr_t);
      }
      a->next = NULL;
      a->attr = r->u.str;
      FREE (r);
      if (prev) {
	prev->next = a;
      }
      prev = a;
	
      li = list_next (li);
      $A(li);
      r = (ActRet *)list_value (li);
      $A(r);
      $A(r->type == R_EXPR);
      a->e = r->u.exp;
      FREE (r);
    }
    list_free ($2);
    return ret;
}}
;

single_prs[act_prs_lang_t *]: EXTERN[prs_expr] arrow bool_expr_id dir
{{X:
    act_prs_lang_t *p;

    NEW (p, act_prs_lang_t);
    p->next = NULL;
    p->type = ACT_PRS_RULE;
    p->u.one.attr = NULL;
    p->u.one.e = (act_prs_expr_t *) $1;
    p->u.one.arrow_type = $2;
    p->u.one.id = $3;
    p->u.one.dir = $4;
    p->u.one.label = 0;
    return p;
}}
| EXTERN[prs_expr] arrow "@" ID dir
{{X:
    act_prs_lang_t *p;

    NEW (p, act_prs_lang_t);
    p->next = NULL;
    p->type = ACT_PRS_RULE;
    p->u.one.attr = NULL;
    p->u.one.e = (act_prs_expr_t *) $1;
    p->u.one.arrow_type = $2;
    p->u.one.id = (ActId *)$4;
    p->u.one.dir = $5;
    p->u.one.label = 1;
    return p;
}}
| ID [ tree_subckt_spec ]
{{X:
    ActRet *r;
    act_prs_lang_t *p;

    if (!OPT_EMPTY ($2)) {
      r = OPT_VALUE ($2);
    }
    else {
      r = NULL;
    }
    if (strcmp ($1, "tree") == 0) {
      if ($0->in_tree) {
	$E("tree { } directive in prs cannot be nested");
      }
      $0->in_tree++;
      if (r && (r->type != R_EXPR)) {
	$E("tree < > parameter must be an expression");
      }
    }
    else if (strcmp ($1, "subckt") == 0) {
      if ($0->in_subckt) {
	$E("subckt { } directive in prs cannot be nested");
      }
      $0->in_subckt++;
      if (r && (r->type != R_STRING)) {
	$E("subckt < > parameter must be a string");
      }
    }
    else {
      $E("Unknown type of body within prs { }: `%s'", $1);
    }
}}
 "{" prs_body "}"
{{X:
    ActRet *r;
    act_prs_lang_t *p;

    if (OPT_EMPTY ($2)) {
      r = NULL;
    }
    else {
      r = OPT_VALUE ($2);
    }
    OPT_FREE ($2);

    NEW (p, act_prs_lang_t);
    p->next = NULL;
    p->u.l.p = $4;

    if (strcmp ($1, "tree") == 0) {
      p->type = ACT_PRS_TREE;
      if (r) {
	$A(r->type == R_EXPR);
	p->u.l.lo = r->u.exp;
      }
      else {
	p->u.l.lo = NULL;
      }
      p->u.l.hi = NULL;
      p->u.l.id = NULL;
      $0->in_tree--;
    }
    else if (strcmp ($1, "subckt") == 0) {
      p->type = ACT_PRS_SUBCKT;
      p->u.l.lo = NULL;
      p->u.l.hi = NULL;
      if (r) {
	$A(r->type == R_STRING);
	p->u.l.id = r->u.str;
      }
      else {
	p->u.l.id = NULL;
      }
      $0->in_subckt--;
    }
    if (r) { FREE (r); }
    return p;
}}
| "(" [":"] ID 
{{X:
    if ($0->scope->Lookup ($3)) {
      $E("Identifier %s already defined in current scope", $3);
    }
    $0->scope->Add ($3, $0->tf->NewPInt ());
    OPT_FREE ($2);
}}
":" !noreal wint_expr [ ".." wint_expr ] ":" prs_body ")"
{{X:
    act_prs_lang_t *p;
    $0->scope->Del ($3);

    NEW (p, act_prs_lang_t);
    p->type = ACT_PRS_LOOP;
    p->next = NULL;
    p->u.l.id = $3;
    p->u.l.lo = $5;
    
    if (OPT_EMPTY ($6)) {
      p->u.l.hi = $5;
      p->u.l.lo = NULL;
    }
    else {
      ActRet *r;
      r = OPT_VALUE ($6);
      $A(r->type == R_EXPR);
      p->u.l.hi = r->u.exp;
      FREE (r);
    }
    OPT_FREE ($6);
    p->u.l.p = $8;
    return p;
}}
/* gate, source, drain */
| "passn" size_spec "(" bool_expr_id "," bool_expr_id "," bool_expr_id ")"
{{X:
    act_prs_lang_t *p;

    NEW (p, act_prs_lang_t);
    p->type = ACT_PRS_GATE;
    p->next = NULL;
    p->u.p.sz = $2;
    p->u.p.g = $4;
    p->u.p.s = $6;
    p->u.p.d = $8;
    p->u.p._g = NULL;

    return p;
}}
| "passp" size_spec "(" bool_expr_id "," bool_expr_id "," bool_expr_id ")"
{{X:
    act_prs_lang_t *p;

    NEW (p, act_prs_lang_t);
    p->type = ACT_PRS_GATE;
    p->next = NULL;
    p->u.p.sz = $2;
    p->u.p._g = $4;
    p->u.p.s = $6;
    p->u.p.d = $8;
    p->u.p.g = NULL;

    return p;
}}
/* n first, then p */
| "transgate" size_spec "(" bool_expr_id "," bool_expr_id "," bool_expr_id "," bool_expr_id ")"
{{X:
    act_prs_lang_t *p;

    NEW (p, act_prs_lang_t);
    p->type = ACT_PRS_GATE;
    p->next = NULL;
    p->u.p.sz = $2;
    p->u.p.g = $4;
    p->u.p._g = $6;
    p->u.p.s = $8;
    p->u.p.d = $10;

    return p;
}}
;

arrow[int]: "->" {{X: return 0; }}
| "=>" {{X: return 1; }}
| "#>" {{X: return 2; }}
;

dir[int]: "+"  {{X: return 1; }}
| "-" {{X: return 0; }}
;

tree_subckt_spec: "<" wint_expr ">"
{{X:
    ActRet *r;
    NEW (r, ActRet);
    r->type = R_EXPR;
    r->u.exp = $2;
    return r;
}}
| "<" STRING ">"
{{X:
    ActRet *r;
    NEW (r, ActRet);
    r->type = R_STRING;
    r->u.str = $2;
    return r;
}}
;

/*
  CONSISTENCY: Check _process_id in prs.c
*/
bool_expr_id[ActId *]: expr_id
{{X:
    int t;
    t = act_type_var ($0->scope, $1);
    if (t == T_ERR) 
    if (t != T_BOOL) {
      $e("Identifier `");
      $1->Print ($f, NULL);
      fprintf ($f, "' is not of type bool");
      exit (1);
    }
    return $1;
}}
;

/*
  CONSISTENCY: MAKE SURE THIS IS CONSISTENT WITH prs.c
  XXX: main change: this one allows real expressions, whereas
      prs.c is integer expressions.

      < width , length, flavor : somethingelse >

*/
size_spec[act_size_spec_t *]: "<" wnumber_expr [ "," wnumber_expr ] [ "," ID [ ":" INT ] ] ">"
{{X:
    act_size_spec_t *s;
    
    NEW (s, act_size_spec_t);
    s->w = $2;
    s->l = NULL;
    s->flavor = ACT_FET_STD;
    s->subflavor = -1;
    
    if (!OPT_EMPTY ($3)) {
      ActRet *r;

      r = OPT_VALUE ($3);
      $A(r->type == R_EXPR);
      s->l = r->u.exp;
      FREE (r);
    }
    OPT_FREE ($3);

    if (!OPT_EMPTY ($4)) {
      ActRet *r;

      r = OPT_VALUE ($4);
      $A(r->type == R_STRING);

      s->flavor = act_fet_string_to_value (r->u.str);
      if (s->flavor == ACT_FET_END) {
	$E("Unknown transistor flavor `%s'", r->u.str);
      }
      FREE (r);
      
      r = OPT_VALUE2 ($4);
      $A(r->type == R_LIST);
      
      if (!OPT_EMPTY (r->u.l)) {
	ActRet *r2;

	r2 = OPT_VALUE (r->u.l);
	$A(r2->type == R_INT);
	s->subflavor = r2->u.ival;
	FREE (r2);
      }
      list_free (r->u.l);
      FREE (r);
    }
    return s;
}}
|  /* empty */
;
  
spec_body: spec_body_item spec_body 
| spec_body_item 
;

spec_body_item: ID "(" { bool_expr_id "," }* ")" 
| "$(" wbool_expr ")"
;

/*
  Sizing body: specify drive strength for rules
*/
lang_size: "size" "{" [ size_body ] "}"
;

strength_directive: bool_expr_id dir "->" wint_expr
;

size_body: { strength_directive ";" }*
;
#line 99 "act.m4"


/* expressions */
#line 1 "expr.m4"
/*************************************************************************
 *
 *  Copyright (c) 2011 Rajit Manohar
 *  All Rights Reserved
 *
 **************************************************************************
 */

/*------------------------------------------------------------------------
 *
 *    
 *   Expression building blocks
 *
 *
 *------------------------------------------------------------------------
 */


/*------------------------------------------------------------------------
 *
 *  I. Array expressions
 *
 *------------------------------------------------------------------------
 */
array_expr[AExpr *]: { array_term "#" }*
{{X:
    AExpr *a, *ret;
    listitem_t *li;

    if (list_length ($1) == 1) {
      ret = (AExpr *) list_value (list_first ($1));
    }
    else {
      li = list_first ($1);
      ret = new AExpr (AExpr::CONCAT, (AExpr *)list_value (li), NULL);
      a = ret;
      for (li = list_next (li); li; li = list_next (li)) {
	a->SetRight (new AExpr (AExpr::CONCAT, (AExpr *)list_value (li), NULL));
	a = a->GetRight();
      }
    }
    list_free ($1);

    /*printf ("Returning %x\n", ret);*/

    return ret;
}}
;

array_term[AExpr *]: "{" { array_expr "," }* "}"
{{X:
    AExpr *a, *ret;
    listitem_t *li;

    li = list_first ($2);
    ret = new AExpr (AExpr::COMMA, (AExpr *)list_value (li), NULL);
    a = ret;
    for (li = list_next (li); li; li = list_next (li)) {
      a->SetRight (new AExpr (AExpr::COMMA, (AExpr *)list_value (li), NULL));
      a = a->GetRight ();
    }
    list_free ($2);
    return ret;
}}
| w_expr
{{X:
    AExpr *a;
    a = new AExpr ($1);
    /*printf ("Expr: %x\n", a);
    printf ("It is: ");
    a->Print (stdout);
    printf ("\n");*/
    return a;
}}
;

opt_array_expr[AExpr *]: [ array_expr ]
{{X:
    ActRet *r;
    AExpr *a;
    if (OPT_EMPTY ($1)) {
      OPT_FREE ($1);
      return NULL;
    }
    else {
      r = OPT_VALUE ($1);
      $A(r->type == R_AEXPR);
      a = r->u.ae;
      FREE (r);
      OPT_FREE ($1);
      return a;
    }
}}
;

/*------------------------------------------------------------------------
 *
 *  II. Identifiers. This could be either a scalar, or a subrange. The
 *  subrange specifier is always the last item in the identifier
 *  (i.e. no dots after it).
 *
 *------------------------------------------------------------------------
 */


expr_id[ActId *]: { base_id "." }*
/* At this point we know the identifier exists, the components exist
 and are accessible, and array accesses are to arrays. */
{{X:
    listitem_t *li;
    ActId *ret, *cur;
    Scope *s;
    InstType *it;
    UserDef *ud;

    /* check we are in _some_ scope! */
    $A($0->scope);

    ret = (ActId *) list_value (li = list_first ($1));
    cur = ret;

    /* check if we are "true", "false", or "self" -- special, we
       aren't going to be found in any scope! */
    if (list_length ($1) == 1 && ret->arrayInfo() == NULL) {
      const char *tmp;
      tmp = ret->getName ();
      if (strcmp (tmp, "true") == 0 || strcmp (tmp, "false") == 0 ||
	  strcmp (tmp, "self") == 0) {
	/* ok done */
	return ret;
      }
    }

    s = $0->scope;
    /* step 1: check that ret exists in the current scope */
    it = s->Lookup (cur);
    if (!it) {
      $E("The identifier `%s' does not exist in the current scope", cur->getName());
    }
    ud = NULL;
    for (li = list_next (li); li; li = list_next (li)) {
      /* it = the inst type of where we are so far; li has the next
	 item after the dot 
	 cur = the ActId that points to where we are right now.
      */
      ud = dynamic_cast<UserDef *>(it->BaseType());
      if (!ud) {
	listitem_t *mi;
	$e("Invalid use of `.' for an identifer that is not a user-defined type: ");
	ret->Print ($f);
	fprintf ($f, "\n");
	exit (1);
      }
      if (list_next (li) && cur->isRange ()) {
	/* a subrange specifier can occur, but it must be the *last*
	   part of the identifier (!) */
	listitem_t *mi;
	$e("Invalid use of array sub-range specifier: ");
	ret->Print ($f);
	fprintf ($f, "\n");
	exit (1);
      }
      if (cur->isDeref()) {
	/* if there is an array specifier, check that the dimensions
	   match */
	if (!it->arrayInfo() || (cur->arrayInfo()->nDims () != it->arrayInfo()->nDims ())) {
	  listitem_t *mi;
	  if (it->arrayInfo ()) {
	    $e("Mismatch in array dimensions (%d v/s %d): ",
	       cur->arrayInfo()->nDims(), it->arrayInfo()->nDims ());
	  }
	  else {
	    $e("Array reference (%d dims) for a non-arrayed identifier: ",
	       cur->arrayInfo()->nDims ());
	  }
	  ret->Print ($f);
	  fprintf ($f, "\n");
	  exit (1);
	}
      }
      /* check that the id fragment exists in the scope of the inst
	 type */
      it = ud->Lookup ((ActId *)list_value (li));
      if (!it) {
	listitem_t *mi;
	$e("Port name `%s' does not exist for the identifier: ", 
	   ((ActId *)list_value (li))->getName());
	ret->Print ($f);
	fprintf ($f, "\n");
	exit (1);
      }
      cur->Append ((ActId *)list_value (li));
      cur = (ActId *) list_value (li);
    }
    
    /* array check! */
    if (cur->isDeref()) {
      /* if there is an array specifier, check that the dimensions
	 match */
      if (!it->arrayInfo() || (cur->arrayInfo()->nDims () != it->arrayInfo()->nDims ())) {
	listitem_t *mi;
	if (it->arrayInfo ()) {
	  $e("Mismatch in array dimensions (%d v/s %d): ",
	     cur->arrayInfo()->nDims(), it->arrayInfo()->nDims ());
	}
	else {
	  $e("Array reference (%d dims) for a non-arrayed identifier: ",
	     cur->arrayInfo()->nDims ());
	}
	ret->Print ($f);
	fprintf ($f, "\n");
	exit (1);
      }
    }

    list_free ($1);
    return ret;
}}
;

base_id[ActId *]: ID [ sparse_range ]
/* completely unchecked */
{{X:
    Array *a;
    ActRet *r;
    if (OPT_EMPTY ($2)) {
      a = NULL;
    }
    else {
      r = OPT_VALUE ($2);
      $A(r->type == R_ARRAY);
      a = r->u.array;
      FREE (r);
    }
    list_free ($2);
    return new ActId ($1, a);
}}
;

/*------------------------------------------------------------------------
 *
 *  III. Walked expressions.
 *
 *------------------------------------------------------------------------
 */
w_expr[Expr *]: expr
{{X:
    Expr *e;
    int tc;

    e = act_walk_X_expr ($0, $1);
    $A($0->scope);
    tc = act_type_expr ($0->scope, e);
    if (tc == T_ERR) {
      $e("Typechecking failed on expression!");
      fprintf ($f, "\n\t%s\n", act_type_errmsg ());
      exit (1);
    }
    if ($0->strict_checking && ((tc & T_STRICT) == 0)) {
      $E("Expressions in port parameter list can only use strict template parameters");
    }
    return e;
}}
;

wnumber_expr[Expr *]: expr
{{X:
    Expr *e;
    int tc;

    e = act_walk_X_expr ($0, $1);
    $A($0->scope);
    tc = act_type_expr ($0->scope, e);
    if (tc == T_ERR) {
      $e("Typechecking failed on expression!");
      fprintf ($f, "\n\t%s\n", act_type_errmsg ());
      exit (1);
    }
    if ($0->strict_checking && ((tc & T_STRICT) == 0)) {
      $E("Expressions in port parameter list can only use strict template parameters");
    }
    if (!(tc & (T_INT|T_REAL))) {
      $E("Expression must be of type int or real");
    }
    return e;
}}
;

/*
  CONSISTENCY: _wint_expr in prs.c
*/
wint_expr[Expr *]: int_expr
{{X:
    Expr *e;
    int tc;

    e = act_walk_X_expr ($0, $1);
    $A($0->scope);
    tc = act_type_expr ($0->scope, e);
    if (tc == T_ERR) {
      $e("Typechecking failed on expression!");
      fprintf ($f, "\n\t%s\n", act_type_errmsg ());
      exit (1);
    }
    if ($0->strict_checking && ((tc & T_STRICT) == 0)) {
      $E("Expressions in port parameter list can only use strict template parameters");
    }
    if (!(tc & T_INT)) {
      $E("Expression must be of type int");
    }
    return e;
}}
;

wbool_expr[Expr *]: bool_expr
{{X:
    Expr *e;
    int tc;

    e = act_walk_X_expr ($0, $1);
    $A($0->scope);
    tc = act_type_expr ($0->scope, e);
    if (tc == T_ERR) {
      $e("Typechecking failed on expression!");
      fprintf ($f, "\n\t%s\n", act_type_errmsg ());
      exit (1);
    }
    if ($0->strict_checking && ((tc & T_STRICT) == 0)) {
      $E("Expressions in port parameter list can only use strict template parameters");
    }
    if (!(tc & T_BOOL)) {
      $E("Expression must be of type bool");
    }
    return e;
}}
;
#line 102 "act.m4"

