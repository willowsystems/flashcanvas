<?php /* $Id$ */

/** 
 * @projectDescription An implementation of the Data URI scheme for IE 6+
 * @author Fabien Ménager
 * @version $Revision$
 * @license MIT License <http://www.opensource.org/licenses/mit-license.php>
 */

$d = reset($_REQUEST);

preg_match('/^data:(?P<mime>[a-z0-9\/+-.]+)(;charset=(?P<charset>[a-z0-9-])+)?(?P<base64>;base64)?\,(?P<data>.*)?/i', $d, $o);

$charset = $o['charset'] ? $o['charset'] : 'US-ASCII';
$mime = $o['mime'] ? $o['mime'] : 'text/plain';
$ext = substr($mime, strrpos($mime, "/") + 1);

header("Content-Type: $mime; charset=$charset");
header('Content-Disposition: attachment; filename="image.' . $ext . '"');
header("Cache-Control: max-age=604800");

echo $o['base64'] ? base64_decode($o['data']) : $o['data'];