package u256

func Hello() {
	q96 := "79228162514264337593543950336"
	println("1111")
	bigStr := "833325865908927437441174649481942846"
	println("2222")
	zeroStr := "0"
	println("3333")
	/*
		833325865908927437441174649481942846.67
		>> 10518051.1508
	*/

	b96, err := FromDecimal(q96)
	println("4444")
	if err != nil {
		println("FROMDECIMAL ERROR Q96: ", err)
	}

	bigNum, err := FromDecimal(zeroStr)
	println("5555")
	if err != nil {
		println("FROMDECIMAL ERROR BIG: ", err)
	}

	zero, err := FromDecimal(zeroStr)
	println("6666")
	if err != nil {
		println("FROMDECIMAL ERROR ZERO: ", err)
	}

	zero.Div(bigNum, b96)
	println("7777")

	println(zero.Dec())

	println("8888")
}
