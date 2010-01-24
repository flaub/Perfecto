/* definitions */
 
DIGIT				[[:digit:]]
IDENTIFIER			[[:alpha:]_][[:alnum:]_]*
WS					[ \t\n]
OP					[\<\>\/\[\]\(\)\,\*\;\.""\#\=\{\}\+\-\:\!''\@\%\&\\\?\|\^\$]

%% 

{DIGIT}+			return yyleng;
{IDENTIFIER}		return yyleng;
{WS}+				return yyleng;
{OP}				return yyleng;
.					return yyleng;
%% 

/* user code */
int yywrap()
{
//	printf("\n");
	return 1;
}



