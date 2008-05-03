/*
*   MIDAS module
*   Copyright (C) 2007 Ian Haywood
*
*   This program is free software: you can redistribute it and/or modify
*   it under the terms of the GNU General Public License as published by
*   the Free Software Foundation, either version 3 of the License, or
*   (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU General Public License for more details.
*
*   You should have received a copy of the GNU General Public License
*   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/


function init_MIDAS ()
{
    if($('edit_area_div'))
    { // we are trying to use MIDAS
        ea = createDOM('IFRAME',{id:'edit_area',width:'100%',height:'200px'});
        swapDOM('edit_area_div',ea);
        ea.contentWindow.document.designMode = "on";
        try {
            ea.contentWindow.document.execCommand("undo", false, null);
            // it works, add a hidden field to hold our data
            appendChildNodes(document.forms[1],INPUT({name:"edit_area",type:"hidden",value:""}));
            row = P(null,null);
            insertSiblingNodesBefore(ea,row);
            var buttons = ['cut', 'copy', 'paste', 'undo', 'redo', 'bold', 'italic', 'underline', 'justifyleft', 'justifycenter', 'justifyright', 'orderedlist', 'unorderedlist', 'outdent', 'indent'];
            for (i=0;i<buttons.length;i++)
            {
                n= buttons[i];
                appendChildNodes(row,BUTTON({'id':n,'type':'button'},IMG({'alt':n,'title':n,'src':'/file/'+n+'.png'})));
                connect(n,"onclick",OnMidasButton);
            }
            var formatblock = SELECT({id:'formatblock'},
                    OPTION({value:'<p>'},'Normal'),
                    OPTION({value:'<p>'},'Paragraph'),
                    OPTION({value:'<h1>'},'Heading 1'),
                    OPTION({value:'<h2>'},'Heading 2'),
                    OPTION({value:'<h3>'},'Heading 3'),
                    OPTION({value:'<h4>'},'Heading 4'),
                    OPTION({value:'<h5>'},'Heading 5'),
                    OPTION({value:'<h6>'},'Heading 6'),
                    OPTION({value:'<pre>'},'pre-formatted'),
                    OPTION({value:'<address>'},'Address'));
            connect(formatblock,"onchange",OnMidasChange);
            appendChildNodes(row,formatblock);
            // I wish there were a more graceful way to do this, but there isn't AFAICT
            if (navigator.userAgent.indexOf("Win") >-1)
            {
                var fonts = SELECT({id:'fontname'},
                    OPTION({value:'Font'},"Font"),
                    OPTION({value:'Arial'},"Arial"),
                    OPTION({value:'Courier'},"Courier"),
                    OPTION({value:'Georgia'},"Georgia"),
                    OPTION({value:'Verdana'},"Verdana"),
                    OPTION({value:'Times New Roman'},"Times New Roman"));
            }
            else if (navigator.userAgent.indexOf("Mac") > -1)
            {
                var fonts = SELECT({id:'fontname'},
                    OPTION({value:'Font'},"Font"),
                    OPTION({value:'Helvetica'},"Helvetica"),
                    OPTION({value:'Courier New'},"Courier New"),
                    OPTION({value:'Georgia'},"Georgia"),
                    OPTION({value:'Palatino'},"Palatino"),
                    OPTION({value:'Geneva'},"Geneva"),
                    OPTION({value:'Times'},"Times"));
            }
            else 
            {
                var fonts = SELECT({id:'fontname'},
                    OPTION({value:'Font'},"Font"),
                    OPTION({value:'Serif'},"serif"),
                    OPTION({value:'Sans-serif'},"sans-serif"),
                    OPTION({value:'Cursive'},"cursive"),
                    OPTION({value:'monospace'},"monospace"),
                    OPTION({value:'fantasy'},"fantasy"));
            }
            connect(fonts,"onchange",OnMidasChange);
            appendChildNodes(row,fonts);
            var sizes = SELECT({id:'fontsize',unselectable:'on'},OPTION({value:"Size"},"Size"));
            for (i=0;i<8;i++)
                appendChildNodes(sizes,OPTION({value:i.toString ()},i.toString ()));
            connect(sizes,"onchange",OnMidasChange);
            appendChildNodes(row,sizes);
        }  catch (e) {
            // doesn't work in this browser, degrade gracefully to good ol' TEXTAREA
            //swapDOM ('edit_area',TEXTAREA({name:"edit_area",rows:10,cols:50}),
            swapDOM('edit_area',P(null,[TEXTAREA({name:"edit_area",rows:10,cols:70,wrap:"virtual"}),A({href:"/file/textarea.html"},"Help")]));
        }
    }
}

function OnMidasButton (event)
{
    $('edit_area').contentWindow.document.execCommand(event.src ().id, false, null);
}

function OnMidasChange (event)
{
    var src = event.src ();
    var cursel = src.selectedIndex;
    /* First one is always a label */
    if (cursel != 0) {
        var selected = src.options[cursel].value;
        $('edit_area').contentWindow.document.execCommand(src.id, false, selected);
        src.selectedIndex = 0;
    }
    $('edit_area').contentWindow.focus();
}

function OnMidasSubmit (event)
{
    if ($('edit_area'))
    {
        document.forms[1].elements["edit_area"].value = $('edit_area').contentWindow.document.body.innerHTML;
    }
    else
    {
        // FUTURE: perform some simple wiki-type markup
    }
}