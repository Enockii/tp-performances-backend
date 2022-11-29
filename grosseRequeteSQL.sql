SELECT 
  post.ID AS ID,
  post.post_title,
  priceData.meta_value AS price,
  imageData.meta_value AS coverImage, 
  bedData.meta_value AS bedrooms_count, 
  bathData.meta_value AS bathrooms_count, 
  surfaceData.meta_value AS surface, 
  typeData.meta_value AS type

FROM tp.wp_posts AS post

INNER JOIN tp.wp_postmeta AS priceData
  ON post.ID = priceData.post_id AND priceData.meta_key = 'price'

INNER JOIN tp.wp_postmeta AS CoverImageData
  ON post.ID = imageData.post_id AND imageData.meta_key = 'coverImage'

INNER JOIN tp.wp_postmeta AS bedData
  ON post.ID = bedData.post_id AND bedData.meta_key = 'bedrooms_count'

INNER JOIN tp.wp_postmeta AS bathData
  ON post.ID = bathData.post_id AND bathData.meta_key = 'bathrooms_count'
  
INNER JOIN tp.wp_postmeta AS surfaceData
  ON post.ID = surfaceData.post_id AND surfaceData.meta_key = 'surface'

INNER JOIN tp.wp_postmeta AS typeData
  ON post.ID = typeData.post_id AND typeData.meta_key = 'type';



SELECT post.ID,
post.post_title,
PriceData.meta_value AS price,
SurfaceData.meta_value AS surface,
TypeData.meta_value AS type,
BedroomsCountData.meta_value AS bedrooms,
BathroomsCountData.meta_value AS bathrooms

FROM tp.wp_posts AS post

INNER JOIN tp.wp_postmeta AS priceData
  ON post.ID = priceData.post_id AND priceData.meta_key = 'price'

INNER JOIN tp.wp_postmeta AS BathroomsCountData
  ON post.ID = BathroomsCountData.post_id AND BathroomsCountData.meta_key = 'bedrooms_count'

INNER JOIN tp.wp_postmeta AS BedroomsCountData
  ON post.ID = BedroomsCountData.post_id AND BedroomsCountData.meta_key = 'bathrooms_count'
  
INNER JOIN tp.wp_postmeta AS surfaceData
  ON post.ID = surfaceData.post_id AND surfaceData.meta_key = 'surface'

INNER JOIN tp.wp_postmeta AS typeData
  ON post.ID = typeData.post_id AND typeData.meta_key = 'type';

INNER JOIN tp.wp_postmeta AS CoverImageData
  ON post.ID = imageData.post_id AND imageData.meta_key = 'coverImage'
















// Si l'utilisateur filtre sur cette donnée, alors on ajoute une condition SQL
if ( isset( $args['surface']['min'] ) )
  $whereClauses[] = 'surface >= :surfaceMin';

if ( isset( $args['surface']['max'] ) )
  $whereClauses[] = 'surface <= :surfaceMax';

if ( isset( $args['price']['min'] ) )
  $whereClauses[] = 'price >= :priceMin'; 

if ( isset( $args['price']['max'] ) )
  $whereClauses[] = 'price <= :priceMax';

if ( isset( $args['rooms'] ) )
  $whereClauses[] = 'bedrooms_count >= :roomsBed';

if ( isset( $args['bathRooms'] ) )
  $whereClauses[] = 'bathrooms_count < :bathRooms';

if ( isset( $args['types'] ) )
  $whereClauses[] = 'types = :types';




// Si on a des clauses WHERE, alors on les ajoute à la requête
if ( count($whereClauses > 0) )
  $query .= " WHERE " . implode( ' AND ', $whereClauses );

// On récupère le PDOStatement
$stmt = $pdo->prepare( $query );

// On associe les placeholder aux valeurs de $args,
// on doit le faire ici, car nous n'avions pas accès au $stmt avant
if ( isset( $args['myFilter'] ) )
  $stmt->bindParam('myFilter', $args['myFilter'], PDO::PARAM_INT);

$stmt->execute();

