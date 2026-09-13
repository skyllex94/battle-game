using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WeaponInfo : MonoBehaviour {

    public enum Modes
    {
        Malee, Straight, Follow, Throw
    }

    public int maxCapacity;
    public int startCapacity;
    public int remainingCapacity;

    public int fillerCount;
    public int startFillerCount;

    public Sprite sprite;
    public GameObject projectile;
    public Modes projectileMode;

}
