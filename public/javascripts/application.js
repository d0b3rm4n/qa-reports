/*
 * This file is part of meego-test-reports
 *
 * Copyright (C) 2010 Nokia Corporation and/or its subsidiary(-ies).
 *
 * Authors: Sami Hangaslammi <sami.hangaslammi@leonidasoy.fi>
 * 			Jarno Keskikangas <jarno.keskikangas@leonidasoy.fi>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA
 *
 */


function handleResultSubmit() {
    var $form = $(this);

    var data = $form.serialize();
    var url = $form.attr('action');

    var $node = $form.closest('td');
    $node.addClass('edit').removeClass('pass fail na').click(handleResultEdit);

    var $span = $node.find('span');
    var result = $form.find('select').val();
    if (result == "1") {
        $node.addClass('pass');
        $span.text('Pass');
    } else if (result == "-1") {
        $node.addClass('fail');
        $span.text('Fail');
    } else {
        $node.addClass('na');
        $span.text('N/A');
    }

    $form.detach();
    $span.show();
    $.post(url, data);

    return false;
}

function handleCommentEdit() {
    var $node = $(this);
    var $div = $node.find('div.content');
    if ($div.is(":hidden")) {
        return false;
    }
    var $testcase = $node.closest('.testcase');
    var $form = $('#comment_edit_form form').clone();
    var $field = $form.find('.comment_field');

    var attachment_url = $div.find('.note_attachment').attr('href') || '';
    var attachment_filename = attachment_url.split('/').pop();

    var $current_attachment = $form.find('div.attachment:not(.add)');
    var $add_attachment = $form.find('div.attachment.add');

    if (attachment_url == '' || attachment_filename == '') {
        $current_attachment.hide();
    }
    else {
        $add_attachment.hide();

        var $attachment_link = $current_attachment.find('#attachment_link');
        $attachment_link.attr('href', attachment_url);
        $attachment_link.html(attachment_filename);

        $current_attachment.find('input').attr('value', attachment_filename);

        $current_attachment.find('.delete').click(function () {
            var $attachment_field = $(this).closest('.field');
            var $current_attachment = $attachment_field.find('div.attachment:not(.add)');
            var $add_attachment = $attachment_field.find('div.attachment.add');

            $current_attachment.hide();
            $current_attachment.find('input').attr('value', '');
            $add_attachment.show();
        });
    }

    var id = $testcase.attr('id').substring(9);
    $form.find('.id_field').val(id);

    var markup = $testcase.find('.comment_markup').text();
    $field.autogrow();
    $field.val(markup);

    $form.submit(handleCommentFormSubmit);
    $form.find('.cancel').click(function() {
        $form.detach();
        $div.show();
        $node.click(handleCommentEdit);
        $node.addClass('edit');
        return false;
    });

    $node.unbind('click');
    $node.removeClass('edit');
    $div.hide();
    $form.insertAfter($div);
    $field.change();
    $field.focus();

    return false;
}

function handleCommentFormSubmit() {
    var $form = $(this);
    var $testcase = $form.closest('.testcase');
    var $div = $testcase.find('.testcase_notes div.content');
    var markup = $form.find('.comment_field').val();

    var data = $form.serialize();
    var url = $form.attr('action');
    $testcase.find('.comment_markup').text(markup);
    var html = formatMarkup(markup);
    $div.html(html);
    $form.hide();
    $div.show();
    $testcase.find('.testcase_notes').click(handleCommentEdit).addClass('edit');

    var options = {datatype: 'xml',
        success: function (responseText, statusText, xhr, $form)  {
            // if the ajaxSubmit method was passed an Options Object with the dataType
            // property set to 'json' then the first argument to the success callback
            // is the json data object returned by the server

            $testcase.find('.testcase_notes').html(responseText);
            fetchBugzillaInfo();
        }
    }
    $form.ajaxSubmit(options);

    return false;
}

function handleTitleEdit() {
    $button = $(this);
    var $content = $button.children('h1').find('span.content');
    if ($content.is(":hidden")) {
        return false;
    }
    var title = $content.text();
    var $form = $('#title_edit_form form').clone();
    var $field = $form.find('.title_field');
    $field.val(title);
    $form.data('original', $content);
    $form.data('button', $button);

    $button.removeClass('editable_text');

    $form.submit(handleTitleEditSubmit);
    $form.find('.save').click(function() {
        $form.submit();
        return false;
    });
    $form.find('.cancel').click(function() {
        $form.detach();
        $content.show();
        $button.addClass('editable_text');
        return false;
    });

    $content.hide();
    $form.insertAfter($content);
    $field.focus();

    return false;
}

function handleTitleEditSubmit() {
    $form = $(this);
    $content = $form.data('original');
    var title = $form.find('.title_field').val();
    $content.text(title);

    var data = $form.serialize();
    var action = $form.attr('action');

    var $button = $form.data('button');
    //$button.text("Saving...");
    $.post(action, data, function() {
        //$button.text("Edit");
    });

    $button.addClass('editable_text');
    $form.detach();
    $content.show();

    return false;
}

function handleDateEdit() {
    $button = $(this);
    var $content = $button.find('span.content').first();
    var $raw = $content.next('span.editmarkup');
    if ($content.is(":hidden")) {
        return false;
    }
    var data = $raw.text();
    var $form = $('#date_edit_form form').clone();
    var $field = $form.find('.date_field');
    $field.val(data);
    $form.data('original', $content).data('raw', $raw).data('button', $button);

    $form.submit(handleDateEditSubmit);
    $form.find('.save').click(function() {
        $form.submit();
        return false;
    });
    $form.find('.cancel').click(function() {
        $form.detach();
        $content.show();
        $button.addClass('editable_text');
        return false;
    });

    $content.hide();
    $form.insertAfter($content);
    $field.focus();
    addDateSelector($field);
    $button.removeClass('editable_text');

    return false;
}

function handleDateEditSubmit() {
    $form = $(this);
    $content = $form.data('original');
    $raw = $form.data('raw');
    var data = $form.find('.date_field').val();
    $raw.text(data);

    var data = $form.serialize();
    var action = $form.attr('action');

    var $button = $form.data('button');
    //$button.text("Saving...");
    $.post(action, data, function(data) {
        $content.text(data);
    });

    $button.addClass('editable_text');
    $form.detach();
    $content.show();

    return false;
}

function handleEditButton() {
    $button = $(this);
    var $div = $button.data('content');
    if ($div.is(":hidden")) {
        return false;
    }
    var $raw = $button.data('raw');
    var fieldName = $div.attr('id');
    var text = $.trim($raw.text());

    var $form = $($('#txt_edit_form form').clone());
    var $area = $($form.find('textarea'));

    $area.attr('name', 'meego_test_session[' + fieldName + ']');
    $area.autogrow();
    $area.val(text);

    $form.data('original', $div);
    $form.data('markup', $raw);
    $form.data('button', $button);

    $form.submit(handleTextEditSubmit);
    $form.find('.save').click(function() {
        $form.submit();
        return false;
    });
    $form.find('.cancel').click(function() {
        $form.detach();
        $div.show();
        $button.addClass('editable_text')
        return false;
    });

    $button.removeClass('editable_text')

    $div.hide();
    $form.insertAfter($div);
    $area.change();
    $area.focus();

    return false;
}

function removeAttachment(report, fileName, callback) {
    $.post("/ajax_remove_attachment", {
        id: report,
        name: fileName
    }, function(data, status){
        if(data.ok==1 && callback!=null) {
            callback.call(this);
        }
    });
};

function toggleRemoveTestCase(eventObject) {
  var $testCaseRow = $(eventObject.target).closest('.testcase');
  var id = $testCaseRow.attr('id').split('-').pop();
  if ($testCaseRow.hasClass('removed')) {
    restoreTestCase(id, function(){});
    linkTestCaseButtons($testCaseRow);
  }
  else {
    removeTestCase(id, function(){});
    unlinkTestCaseButtons($testCaseRow);
  }

  $nftRows = $('.testcase-nft-' + id.toString());
  if ($nftRows.length == 0) {
    $testCaseRow.toggleClass('removed');
  } else {
    $nftRows.toggleClass('removed');
  }

  $testCaseRow.find('.testcase_name').toggleClass('removed');
  $testCaseRow.find('.testcase_name a').toggleClass('remove_list_item');
  $testCaseRow.find('.testcase_name a').toggleClass('undo_remove_list_item');
  $testCaseRow.find('.testcase_notes').toggleClass('edit');
  $testCaseRow.find('.testcase_result').toggleClass('edit');
}

function removeTestCase(id, callback) {
    $.post("/ajax_remove_testcase", {
        id: id
    }, function(data, status) {
        if (data.ok == 1 && callback != null) {
    	     callback.call(this);
    	}
    });
}

function restoreTestCase(id, callback) {
    $.post("/ajax_restore_testcase", {
      id:         id,
    }, function(data, status) {
      if (data.ok == 1 && callback != null) {
        callback.call(this);
      }
    });
}


(function($) {

    /*
     * Auto-growing textareas; technique ripped from Facebook
     */
    $.fn.autogrow = function(options) {

        this.filter('textarea').each(function() {

            var $this = $(this),
                    minHeight = $this.height(),
                    lineHeight = $this.css('lineHeight');

            var shadow = $('<div></div>').css({
                position:   'absolute',
                top:        -10000,
                left:       -10000,
                width:      $(this).width() - parseInt($this.css('paddingLeft')) - parseInt($this.css('paddingRight')),
                fontSize:   $this.css('fontSize'),
                fontFamily: $this.css('fontFamily'),
                lineHeight: $this.css('lineHeight'),
                resize:     'none'
            }).appendTo(document.body);

            var update = function() {

                var times = function(string, number) {
                    var _res = '';
                    for (var i = 0; i < number; i ++) {
                        _res = _res + string;
                    }
                    return _res;
                };

                var val = this.value.replace(/</g, '&lt;')
                        .replace(/>/g, '&gt;')
                        .replace(/&/g, '&amp;')
                        .replace(/\n$/, '<br/>&nbsp;')
                        .replace(/\n/g, '<br/>')
                        .replace(/ {2,}/g, function(space) {
                    return times('&nbsp;', space.length - 1) + ' '
                });

                shadow.html(val);
                $(this).css('height', Math.max(shadow.height() + 20, minHeight));

            }

            $(this).change(update).keyup(update).keydown(update);

            update.apply(this);

        });

        return this;

    }

})(jQuery);

function handleTextEditSubmit() {
    var $form = $(this);
    var $original = $form.data('original');
    var $markup = $form.data('markup');
    var $area = $form.find('textarea');

    var text = $area.val();
    var $button = $form.data("button");
    $button.addClass('editable_text');

    if ($markup.text() == text) {
        // No changes were made.
        $form.detach();
        $original.show();
        return false;
    }

    $markup.text(text);

    var data = $form.serialize();
    var action = $form.attr("action");
    $.post(action, data, function() {});

    $original.html(formatMarkup(text));
    $form.detach();
    $original.show();

    fetchBugzillaInfo();
    return false;
}

function applyBugzillaInfo(node, info) {
    var $node = $(node);
    if (info == undefined) {
        $node.addClass("invalid");
    } else {
        var status = info.status;
        if (status == 'RESOLVED' || status == 'VERIFIED') {
            $node.addClass("resolved");
            status = info.resolution;
        } else {
            $node.addClass("unresolved");
        }

        var text = info.summary;
        if ($node.closest('td.testcase_notes').length != 0) {
            text = text + " (" + status + ")";
            $node.attr("title", text);
        } else if($node.hasClass("bugzilla_append")) {
            text = text + " (" + status + ")";
            $node.after("<span> - "  + text +"</span>");
        } else {
            $node.text(text);
            $node.attr("title", status);
        }
    }
    $node.removeClass("fetch");
}

function fetchBugzillaInfo() {
    var bugIds = [];
    var searchUrl = "/fetch_bugzilla_data";

    var links = $('.bugzilla.fetch');
    links.each(function(i, node) {
        var id = $.trim($(node).text());
        if (id in bugzillaCache) {
            applyBugzillaInfo(node, bugzillaCache[id]);
        } else {
            if ($.inArray(id, bugIds) == -1) bugIds.push(id);
        }
    });

    if (bugIds.length == 0) return;
    $.get(searchUrl, "bugids[]=" + bugIds.toString(), function(csv) {
        var data = CSVToArray(csv);
        var hash = [];
        for (var i = 1; i < data.length; i++) {
            var row = data[i];
            var id = row[0];
            var summary = row[1];
            var status = row[2];
            var resolution = row[3];
            hash[id.toString()] = {summary: row[1], status:row[2], resolution:row[3]};
        }

        $('.bugzilla.fetch').each(function(i, node) {
            var info;
            var id = $.trim($(node).text());
            if (id in bugzillaCache) {
                info = bugzillaCache[id];
            } else {
                info = hash[id];
                if (info != undefined) {
                    bugzillaCache[id] = info;
                }
            }
            applyBugzillaInfo(node, info);
        });
    });
}

function formatMarkup(s) {
    s = htmlEscape(s);

    lines = s.split('\n');
    var html = "";
    var ul = false;
    for (var i = 0; i < lines.length; ++i) {
        var line = $.trim(lines[i]);
        if (ul && !/^\*/.test(line)) {
            html += '</ul>';
            ul = false;
        } else if (line == '') {
            html += "<br/>";
        }
        if (line == '') {
            continue;
        }
        line = line.replace(/'''''(.+?)'''''/g, "<b><i>$1</i></b>");
        line = line.replace(/'''(.+?)'''/g, "<b>$1</b>");
        line = line.replace(/''(.+?)''/g, "<i>$1</i>");
        line = line.replace(/http\:\/\/([^\/]+)\/show_bug\.cgi\?id=(\d+)/g, "<a class=\"bugzilla fetch bugzilla_append\" href=\"http://$1/show_bug.cgi?id=$2\">$2</a>");
        line = line.replace(/\[\[(http[s]?:\/\/.+?) (.+?)\]\]/g, "<a href=\"$1\">$2</a>");
        line = line.replace(/\[\[(\d+)\]\]/g, "<a class=\"bugzilla fetch bugzilla_append\" href=\"" + BUGZILLA_URI + "$1\">$1</a>");

        var match;
        line = line.replace(/^====\s*(.+)\s*====$/, "<h5>$1</h5>");
        line = line.replace(/^===\s*(.+)\s*===$/, "<h4>$1</h4>");
        line = line.replace(/^==\s*(.+)\s*==$/, "<h3>$1</h3>");
        match = /^\*(.+)$/.exec(line);
        if (match) {
            if (!ul) {
                html += "<ul>";
                ul = true;
            }
            html += "<li>" + match[1] + "</li>";
        } else if (!/^<h/.test(line)) {
            html += line + "<br/>";
        } else {
            html += line;
        }
    }
    return html;
}

function setTableLoaderSize(tableID, loaderID) {
		t = $(tableID);
//		w = t.width();
		h = t.height();
		$(loaderID).height(h);
	}

// This will parse a delimited string into an array of
// arrays. The default delimiter is the comma, but this
// can be overriden in the second argument.
//
// Originally written by Ben Nadel
// http://www.bennadel.com/blog/1504-Ask-Ben-Parsing-CSV-Strings-With-Javascript-Exec-Regular-Expression-Command.htm
function CSVToArray(strData, strDelimiter) {
    // Check to see if the delimiter is defined. If not,
    // then default to comma.
    strDelimiter = (strDelimiter || ",");

    // Create a regular expression to parse the CSV values.
    var objPattern = new RegExp(("(\\" + strDelimiter + "|\\r?\\n|\\r|^)" +
                        // Quoted fields.
                            "(?:\"([^\"]*(?:\"\"[^\"]*)*)\"|" +
                        // Standard fields.
                            "([^\"\\" + strDelimiter + "\\r\\n]*))"),"gi");


    // Create an array to hold our data. Give the array
    // a default empty first row.
    var arrData = [[]];

    // Create an array to hold our individual pattern
    // matching groups.
    var arrMatches = null;


    // Keep looping over the regular expression matches
    // until we can no longer find a match.
    while (arrMatches = objPattern.exec(strData)) {

        // Get the delimiter that was found.
        var strMatchedDelimiter = arrMatches[ 1 ];

        // Check to see if the given delimiter has a length
        // (is not the start of string) and if it matches
        // field delimiter. If id does not, then we know
        // that this delimiter is a row delimiter.
        if (strMatchedDelimiter.length && (strMatchedDelimiter != strDelimiter)) {
            // Since we have reached a new row of data,
            // add an empty row to our data array.
            arrData.push([]);
        }

        // Now that we have our delimiter out of the way,
        // let's check to see which kind of value we
        // captured (quoted or unquoted).
        if (arrMatches[ 2 ]) {
            // We found a quoted value. When we capture
            // this value, unescape any double quotes.
            var strMatchedValue = arrMatches[ 2 ].replace(new RegExp("\"\"", "g"),"\"");
        } else {
            // We found a non-quoted value.
            strMatchedValue = arrMatches[ 3 ];
        }

        // Now that we have our value string, let's add
        // it to the data array.
        arrData[ arrData.length - 1 ].push(strMatchedValue);
    }
    // Return the parsed data.
    return( arrData );
}

function filterResults(rowsToHide, typeText) {
    var updateToggle = function($tbody, $this) {
        var count = $tbody.find("tr:hidden").length;
        if(count > 0) {
            $this.text("+ see " + count + " " + typeText);
        } else {
            $this.text("- hide " + typeText);
        }
        if($tbody.find(rowsToHide).length == 0) {
            $this.hide();
        }
    }

    var updateToggles = function() {
        $("a.see_all_toggle").each(function() {
          $tbody = $(this).parents("tbody").next("tbody");
          updateToggle($tbody, $(this));
        });
    }



    $(".see_history_button").click(function(){
    	//setTableLoaderSize('#detailed_functional_test_results', '#history_loader');
    	//$('#history_loader').show();
    	//history loader should be visible during AJAX loading
      $("#detailed_functional_test_results").hide();
      $history.show();
      $history.find(".see_history_button").addClass("active");
      return false;
    });

    $(".see_all_button").click(function(){
        $("a.sort_btn").removeClass("active");
        $(this).addClass("active");
        $(rowsToHide).show();
        updateToggles();
        return false;
    });

    $(".see_only_failed_button").click(function(){
        $("a.sort_btn").removeClass("active");
        $(this).addClass("active");
        $(rowsToHide).hide();
        updateToggles();
        return false;
    });

    updateToggles();
    $("a.see_all_toggle").each(function() {
        $(this).click(function(index, item) {
            var $this = $(this);
            $tbody = $this.parents("tbody").next("tbody");
            $tbody.find(rowsToHide).toggle();
            updateToggle($tbody, $this);
            return false;
        });
    });

    var $detail  = $("table.detailed_results").first();
    var $history = $("table.detailed_results.history");
    $history.find(".see_all_button").click(function(){
        $history.hide();
        $detail.show();
        $detail.find(".see_all_button").click();
    });
    $history.find(".see_only_failed_button").click(function(){
        $history.hide();
        $detail.show();
        $detail.find(".see_only_failed_button").click();
    });
}

jQuery(function($) {

    function dragenter(e) {
        e.stopPropagation();
        e.preventDefault();

        $('#dropbox').addClass('draghover');
        return false;
    }

    function dragover(e) {
        e.stopPropagation();
        e.preventDefault();

        $('#dropbox').addClass('draghover');
        return false;
    }

    function dragleave(e) {
        e.stopPropagation();
        e.preventDefault();

        $('#dropbox').removeClass('draghover');
        return false;
    }


    function drop(e) {
        var files;

        e.stopPropagation();
        e.preventDefault();


        $('#dropbox').removeClass('draghover');
        $('#dropbox').addClass('dropped');

        // get files from drag and drop datatransfer or files in case of field change
        if (typeof e.originalEvent.dataTransfer == "undefined") {
            files = e.originalEvent.target.files;
        } else {
            files = e.originalEvent.dataTransfer.files;
        }

        handleFiles(files);
        return false;
    }

    // Kind of a hack, clean up
    var firstdrop = true;
    var fileid = 1;
    var queue = [];

    function handleFiles(files) {
        // process file list
        for (var i = 0; i < files.length; i++) {
            var file = files[i];

            var file_extension = file.name.split('.').pop().toLowerCase();
            var allowed_extensions = ['xml','csv'];

            if (file.fileSize < 1048576 &&
                    jQuery.inArray(file_extension, allowed_extensions) != -1) {

                // First succesful drag'n drop, remove template text
                if (firstdrop) {
                    $('#dropbox').text("");
                    firstdrop = false;
                }

                file.id = 'file' + fileid;
                fileid = fileid + 1;

                var source = $("script[name=attachment]").html();
                var template = Handlebars.compile(source);
                var data = { "filename": file.name, "fileid": file.id };
                result = template(data);
                $("#dropbox").append(result);

                queue.push(file);
            }
        }

        // trigger first item
        sendItemInQueue();
    }

    function handleAjaxResponse() {
        // Is data transfer completed?
        if (this.readyState === 4) {
            // Enable send button until the data transfer has been finished
            $('form input[type=submit]').removeAttr('disabled');

            // Update dropbox
            var response = JSON.parse(this.responseText);
            var tag = '#' + response.fileid;
            $(tag + " input").attr('value', response.url);
            $(tag + " img").hide();

            // process next item
            sendItemInQueue();
        }
    }

    // Send a file from queue
    function sendItemInQueue() {
        if (queue.length > 0) {
            var file = queue.pop();
            var xhr = new XMLHttpRequest();
            xhr.open('post', '/upload_report/', true);

            xhr.onreadystatechange = handleAjaxResponse;

            xhr.setRequestHeader('Content-Type', 'application/octet-stream'); // multipart/form-data
            xhr.setRequestHeader('If-Modified-Since', 'Mon, 26 Jul 1997 05:00:00 GMT');
            xhr.setRequestHeader('Cache-Control', 'no-cache');
            xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
            xhr.setRequestHeader('X-File-Name', file.fileName);
            xhr.setRequestHeader('X-File-Size', file.fileSize);
            xhr.setRequestHeader('X-File-Type', file.type);
            xhr.setRequestHeader('X-File-Id', file.id);
            xhr.send(file);

            // Disable send button until the data transfer has been finished
            $('form input[type=submit]').attr('disabled', 'true');
        }
    }

    // Bind event listeners
    if (typeof window.FileReader === "function") {
        $('#only_browse').remove();
        $('#dragndrop_and_browse').show();
        // We have file API
        $('#dropbox').bind('dragenter', dragenter)
                     .bind('dragover', dragover)
                     .bind('dragleave', dragleave)
                     .bind('drop', drop);
    } else {
        // Fallback to normal file input
        $('#dragndrop_and_browse').remove();
    }
});
