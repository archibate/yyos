data Move = Up | Down | Left | Right

type Grid = [[Int]]

start :: Grid
start = replicate 3 (replicate 4 0) ++ [0,0,2,2]

merge :: [Int] -> [Int]
merge xs = merged ++ padding where
	padding  = replicate (length xs - length merged) 0
	merged   = combine $ filter (/= 0) xs
	combine (x:y:xs) | x == y   = x * 2 : combine xs
			 | otherwise = x  : combine (y:xs)
	combine x = x
