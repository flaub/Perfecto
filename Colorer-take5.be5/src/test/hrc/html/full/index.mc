<html>
<body>
<b>������ ��� �����</b> - <& '../include/dates.mc:now' &>
<b>������ ��� �����</b> - <% $arg1 == 7 ? 'yes' : 'no' %>

here goes some html

%	if($a = 5)  {          # ����� % � ����� ������ ������ ����� ��������� ������������ ������� �� �����
		<center><b>a = 5!</b></center>
%	}                      # ��������� �������� �� "%" � �� ����� ������

<%perl>     # sample of %perl section
	# � ���� � ��������� �������� ������ ���� �������� ���������
	# here goes huge amount of perl code
	
	my @arr;
	@arr = split;
{
</%perl>

  <b>adsfasdf</b>

<%perl>

};
	$m->out($arr[1]);
	# ...
</%perl>

</body>
</html>

<%init>     # sample of %init section
my $a = 5;
</%init>

<%args>
$arg1 => 7   # sample of %args section
</%args>

<%flags>        # sample of %flags section
inherit => undef
</%flags>

<%filter>        # sample of %filter section
s{\[link\s+?url\s*?=\s*?"(.+?)"\s*?\](.+?)\[/link\]} {<a href="$1">$2</a>}ig;
s{\[link\s+?url\s*?=\s*?"(.+?)"\s+?popup\s*?\](.+?)\[/link\]} {<a href="$1" target="_blank">$2</a>}ig;
</%filter>

<%once>
	# perl code ...
	# ...
</%once>

<%method right_column>
	<& shared/rightcolumn/articlehelp.mc &>
	blah-blah html
</%method>

<%def .td>
%	if($config->{$item}) {
		<td align="center">
			<% $data->{$item} %>
		</td>
%	}
<%args>
$config
$data
$item
</%args>
</%def>
