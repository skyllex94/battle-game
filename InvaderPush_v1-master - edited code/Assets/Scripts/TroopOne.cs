using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TroopOne : MonoBehaviour {

    public AlliesBlueprint allieBlueprint1;
    public AlliesBlueprint allieBlueprint2;

    public Transform spawnpoint;


    public void InstanceOfAllie ()
    {
        if (PlayerMoney.money < allieBlueprint1.cost)
        {
            Debug.Log("Not enough money!");
            return;
        }
        PlayerMoney.money -= allieBlueprint1.cost;
        Instantiate(allieBlueprint1.prefab.transform, spawnpoint.position, spawnpoint.rotation);
    }

    public void InstanceOfAllie2()
    {
        if (PlayerMoney.money < allieBlueprint2.cost)
        {
            Debug.Log("Not enough money!");
            return;
        }
        PlayerMoney.money -= allieBlueprint2.cost;
        Instantiate(allieBlueprint2.prefab.transform, spawnpoint.position, spawnpoint.rotation);
    }
}
