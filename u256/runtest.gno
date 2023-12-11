package u256

func Hello() {
	q96 := "79228162514264337593543950336"
	bigStr := "833325865908927437441174649481942846"
	zeroStr := "0"
	/*
		833325865908927437441174649481942846.67
		>> 10518051.1508
	*/

	b96, err := FromDecimal(q96)
	if err != nil {
		println("FROMDECIMAL ERROR Q96: ", err)
	}

	bigNum, err := FromDecimal(zeroStr)
	if err != nil {
		println("FROMDECIMAL ERROR BIG: ", err)
	}

	zero, err := FromDecimal(zeroStr)
	if err != nil {
		println("FROMDECIMAL ERROR ZERO: ", err)
	}

	zero.Div(bigNum, b96)

	println(zero.Dec())
}
