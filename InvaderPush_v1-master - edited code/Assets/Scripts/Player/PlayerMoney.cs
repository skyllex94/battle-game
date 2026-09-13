using UnityEngine;
using System.Collections;
using System.Collections.Generic;

public class PlayerMoney : MonoBehaviour {

    public static int money;
    public int startingMoney = 500;
	void Start () 
    {
        money = startingMoney;
	}
}
