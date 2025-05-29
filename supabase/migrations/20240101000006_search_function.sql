-- Drop existing function if it exists
DROP FUNCTION IF EXISTS search_loops;

-- Create a function for advanced loop search
CREATE OR REPLACE FUNCTION search_loops(
  search_query text DEFAULT NULL,
  bpm_min integer DEFAULT NULL,
  bpm_max integer DEFAULT NULL,
  key_signature text DEFAULT NULL,
  sort_by text DEFAULT 'newest',
  limit_count integer DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  title text,
  producer_id uuid,
  audio_url text,
  bpm integer,
  key text,
  downloads integer,
  average_rating double precision, -- Changed from numeric to double precision
  created_at timestamptz,
  producer_username text,
  producer_avatar_url text
) AS $$
#variable_conflict use_column
BEGIN
  RETURN QUERY
  SELECT 
    l.id,
    l.title,
    l.producer_id,
    l.audio_url,
    l.bpm,
    l.key,
    l.downloads,
    CAST(l.average_rating AS double precision), -- Cast to double precision
    l.created_at,
    p.username as producer_username,
    p.avatar_url as producer_avatar_url
  FROM loops l
  JOIN profiles p ON l.producer_id = p.id
  WHERE
    (search_query IS NULL OR 
      l.title ILIKE '%' || search_query || '%' OR
      p.username ILIKE '%' || search_query || '%'
    )
    AND (bpm_min IS NULL OR l.bpm >= bpm_min)
    AND (bpm_max IS NULL OR l.bpm <= bpm_max)
    AND (key_signature IS NULL OR l.key = key_signature)
  ORDER BY
    CASE sort_by
      WHEN 'downloads' THEN l.downloads
      WHEN 'rating' THEN l.average_rating
      ELSE NULL
    END DESC NULLS LAST,
    CASE 
      WHEN sort_by = 'newest' OR sort_by IS NULL THEN l.created_at
      ELSE NULL
    END DESC NULLS LAST
  LIMIT COALESCE(limit_count, 50);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;